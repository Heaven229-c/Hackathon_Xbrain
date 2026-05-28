import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
  AlertTriangle,
  ArrowLeft,
  Bot,
  CheckCircle2,
  Clock3,
  FileText,
  Loader2,
  RefreshCw,
  Send,
  Trash2,
  Upload,
  User,
} from 'lucide-react';

import Header from '../components/layout/Header';
import { Badge } from '../components/ui/badge';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { getApiUrl, getAuthToken, getTenantId, getUserRole, tenantFetch } from '../lib/api';

type DocumentStatus = 'PENDING' | 'UPLOADED' | 'INDEXING' | 'READY' | 'ERROR' | 'UNKNOWN';

interface FileRecord {
  id: string;
  name: string;
  kbId: string;
  status: DocumentStatus;
  errorMessage?: string;
  ingestionJobId?: string;
  updatedAt?: string;
}

interface DocumentResponseItem {
  document_id: string;
  filename: string;
  status?: string;
  error_message?: string;
  ingestion_job_id?: string;
  updated_at?: string;
}

interface UploadInitResponse {
  document_id: string;
  upload_url: {
    url: string;
    fields: Record<string, string>;
  };
  error?: string;
}

interface ChatResponse {
  answer: string;
  sources?: string[];
}

interface ChatMessage {
  id: string;
  role: 'user' | 'ai';
  content: string;
  source?: string;
}

const initialGreeting: ChatMessage = {
  id: 'msg_0',
  role: 'ai',
  content: 'Xin chao! Toi da san sang tra loi cau hoi dua tren tai lieu trong thu muc nay. Ban muon hoi gi?',
};

const processingStatuses: DocumentStatus[] = ['PENDING', 'UPLOADED', 'INDEXING'];

function normalizeDocumentStatus(status?: string): DocumentStatus {
  const normalized = status?.toUpperCase();

  if (
    normalized === 'PENDING' ||
    normalized === 'UPLOADED' ||
    normalized === 'INDEXING' ||
    normalized === 'READY' ||
    normalized === 'ERROR'
  ) {
    return normalized;
  }

  return 'UNKNOWN';
}

function isProcessingStatus(status: DocumentStatus) {
  return processingStatuses.includes(status);
}

function getStatusBadgeClass(status: DocumentStatus) {
  if (status === 'READY') return 'border-emerald-200 bg-emerald-50 text-emerald-700';
  if (status === 'ERROR') return 'border-red-200 bg-red-50 text-red-700';
  if (status === 'INDEXING') return 'border-blue-200 bg-blue-50 text-blue-700';
  if (status === 'UPLOADED') return 'border-amber-200 bg-amber-50 text-amber-700';
  return 'border-slate-200 bg-slate-50 text-slate-600';
}

function getChatPlaceholder(files: FileRecord[], hasReadyDocument: boolean) {
  if (hasReadyDocument) return 'Ask a question about your documents...';
  if (files.length === 0) return 'Upload a PDF or DOCX before chatting...';
  if (files.some((file) => isProcessingStatus(file.status))) return 'Syncing documents with Bedrock Knowledge Base...';
  if (files.some((file) => file.status === 'ERROR')) return 'Document sync failed. Delete it or upload another file...';
  return 'Waiting for a ready document...';
}

function formatRelativeStatusTime(value?: string) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

export default function KBDetailPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const kbId = searchParams.get('kb_id');
  const kbName = searchParams.get('name') ?? kbId ?? 'Knowledge Base';
  const userRole = getUserRole();
  const canManageDocuments = userRole === 'company_admin';

  const [files, setFiles] = useState<FileRecord[]>([]);
  const [messages, setMessages] = useState<ChatMessage[]>(() => [initialGreeting]);
  const [inputValue, setInputValue] = useState('');
  const [isUploading, setIsUploading] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [deletingFileId, setDeletingFileId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [isThinking, setIsThinking] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const hasReadyDocument = files.some((file) => file.status === 'READY');
  const chatDisabled = isThinking || !hasReadyDocument;
  const readyCount = files.filter((file) => file.status === 'READY').length;
  const processingCount = files.filter((file) => isProcessingStatus(file.status)).length;
  const errorCount = files.filter((file) => file.status === 'ERROR').length;
  const chatPlaceholder = getChatPlaceholder(files, hasReadyDocument);

  const fetchDocuments = useCallback(async (showSpinner = false) => {
    if (!kbId) return;

    try {
      if (showSpinner) setIsRefreshing(true);
      const apiUrl = getApiUrl();
      if (!apiUrl) return;

      const res = await tenantFetch(`${apiUrl}/documents?workspace_id=${kbId}`);
      if (!res.ok) {
        setStatusMessage('Could not refresh document status.');
        return;
      }

      const data = await res.json();
      const fetchedFiles = data.documents.map((document: DocumentResponseItem) => ({
        id: document.document_id,
        name: document.filename,
        kbId,
        status: normalizeDocumentStatus(document.status),
        errorMessage: document.error_message,
        ingestionJobId: document.ingestion_job_id,
        updatedAt: document.updated_at,
      }));
      setFiles(fetchedFiles);
      setStatusMessage(null);
    } catch (err) {
      console.error('Failed to load documents', err);
      setStatusMessage('Could not refresh document status.');
    } finally {
      if (showSpinner) setIsRefreshing(false);
    }
  }, [kbId]);

  useEffect(() => {
    if (!kbId) {
      navigate('/knowledge-bases');
      return;
    }

    const tenantId = getTenantId();
    const authToken = getAuthToken();
    if (!tenantId || !authToken) {
      navigate('/');
      return;
    }
  }, [kbId, navigate]);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => {
      void fetchDocuments();
    }, 0);

    return () => window.clearTimeout(timeoutId);
  }, [fetchDocuments]);

  useEffect(() => {
    if (!files.some((file) => isProcessingStatus(file.status))) return;

    const intervalId = window.setInterval(() => {
      void fetchDocuments();
    }, 5000);

    return () => window.clearInterval(intervalId);
  }, [fetchDocuments, files]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isThinking]);

  const handleFileUploadTrigger = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file || !kbId) return;

    setIsUploading(true);

    try {
      const apiUrl = getApiUrl();
      if (!apiUrl) {
        alert('VITE_API_URL is not configured.');
        return;
      }

      const initRes = await tenantFetch(`${apiUrl}/documents/upload`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          workspace_id: kbId,
          filename: file.name,
        }),
      });

      const initData = (await initRes.json()) as UploadInitResponse;

      if (!initRes.ok) {
        throw new Error(initData.error || 'Failed to initialize upload');
      }

      const formData = new FormData();
      Object.entries(initData.upload_url.fields).forEach(([key, value]) => {
        formData.append(key, value);
      });
      formData.append('file', file);

      const s3Res = await fetch(initData.upload_url.url, {
        method: 'POST',
        body: formData,
      });

      if (!s3Res.ok) {
        throw new Error('Failed to upload to S3');
      }

      setFiles((prev) => [
        ...prev,
        {
          id: initData.document_id,
          name: file.name,
          kbId,
          status: 'UPLOADED',
        },
      ]);
      setStatusMessage('Upload complete. Sync has started automatically.');
      void fetchDocuments();

      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    } catch (error) {
      console.error('Upload error:', error);
      alert('Upload failed. Please check the console and try again.');
    } finally {
      setIsUploading(false);
    }
  };

  const handleDeleteFile = async (file: FileRecord) => {
    if (!canManageDocuments) return;

    const confirmed = window.confirm(`Delete "${file.name}" from this knowledge base?`);
    if (!confirmed) return;

    try {
      setDeletingFileId(file.id);
      const apiUrl = getApiUrl();
      if (!apiUrl) throw new Error('VITE_API_URL is not configured.');

      const response = await tenantFetch(`${apiUrl}/documents?document_id=${encodeURIComponent(file.id)}`, {
        method: 'DELETE',
      });
      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to delete document');
      }

      setFiles((prev) => prev.filter((item) => item.id !== file.id));
      setStatusMessage('Document deleted.');
    } catch (error) {
      console.error('Delete document error:', error);
      alert(error instanceof Error ? error.message : 'Failed to delete document');
    } finally {
      setDeletingFileId(null);
    }
  };

  const handleSendMessage = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!inputValue.trim() || !kbId || !hasReadyDocument) return;

    const userMsg: ChatMessage = {
      id: `msg_${Date.now()}`,
      role: 'user',
      content: inputValue.trim(),
    };

    setMessages((prev) => [...prev, userMsg]);
    setInputValue('');
    setIsThinking(true);

    try {
      const apiUrl = getApiUrl();
      if (!apiUrl) throw new Error('VITE_API_URL is not configured.');

      const response = await tenantFetch(`${apiUrl}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: userMsg.content,
          workspace_id: kbId,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to call AI backend');
      }

      const data = (await response.json()) as ChatResponse;

      setMessages((prev) => [
        ...prev,
        {
          id: `msg_${Date.now() + 1}`,
          role: 'ai',
          content: data.answer,
          source: data.sources?.length ? data.sources.join(', ') : undefined,
        },
      ]);
    } catch (error) {
      console.error('Chat error:', error);
      setMessages((prev) => [
        ...prev,
        {
          id: `msg_${Date.now() + 1}`,
          role: 'ai',
          content: 'Sorry, the AI service is unavailable. Please try again.',
        },
      ]);
    } finally {
      setIsThinking(false);
    }
  };

  return (
    <div className="h-screen flex flex-col bg-white">
      <Header />

      <main className="flex-1 overflow-hidden flex flex-col md:flex-row">
        <div className="w-full md:w-[30%] border-r border-slate-200 flex flex-col bg-slate-50/50">
          <div className="p-4 border-b border-slate-200">
            <Button
              variant="ghost"
              size="sm"
              className="mb-4 text-slate-500 hover:text-slate-900 -ml-2"
              onClick={() => navigate('/knowledge-bases')}
            >
              <ArrowLeft className="h-4 w-4 mr-2" />
              Back to Knowledge Bases
            </Button>
            <h2 className="font-semibold text-lg truncate" title={kbName}>
              {kbName}
            </h2>
            <p className="text-xs text-slate-500 mt-1">
              Uploads sync automatically. Chat unlocks when at least one document is READY.
            </p>
          </div>

          <div className="p-4 space-y-3">
            <input
              type="file"
              ref={fileInputRef}
              onChange={handleFileChange}
              className="hidden"
              accept=".pdf,.docx"
            />
            <Button
              className="w-full bg-slate-900 text-white hover:bg-slate-800"
              onClick={handleFileUploadTrigger}
              disabled={isUploading}
            >
              {isUploading ? (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <Upload className="h-4 w-4 mr-2" />
              )}
              {isUploading ? 'Uploading...' : '+ Upload File'}
            </Button>
            <p className="text-[10px] text-center text-slate-500">Accepts .pdf, .docx up to 10 MB</p>

            <div className="grid grid-cols-3 gap-2">
              <div className="rounded-md border border-emerald-200 bg-emerald-50 p-2">
                <div className="flex items-center gap-1 text-emerald-700">
                  <CheckCircle2 className="h-3.5 w-3.5" />
                  <span className="text-[10px] font-medium uppercase">Ready</span>
                </div>
                <p className="mt-1 text-lg font-semibold text-emerald-900">{readyCount}</p>
              </div>
              <div className="rounded-md border border-blue-200 bg-blue-50 p-2">
                <div className="flex items-center gap-1 text-blue-700">
                  <Clock3 className="h-3.5 w-3.5" />
                  <span className="text-[10px] font-medium uppercase">Syncing</span>
                </div>
                <p className="mt-1 text-lg font-semibold text-blue-900">{processingCount}</p>
              </div>
              <div className="rounded-md border border-red-200 bg-red-50 p-2">
                <div className="flex items-center gap-1 text-red-700">
                  <AlertTriangle className="h-3.5 w-3.5" />
                  <span className="text-[10px] font-medium uppercase">Error</span>
                </div>
                <p className="mt-1 text-lg font-semibold text-red-900">{errorCount}</p>
              </div>
            </div>

            <Button
              variant="outline"
              size="sm"
              className="w-full"
              onClick={() => void fetchDocuments(true)}
              disabled={isRefreshing}
            >
              <RefreshCw className={`h-4 w-4 mr-2 ${isRefreshing ? 'animate-spin' : ''}`} />
              Refresh sync status
            </Button>

            {statusMessage && (
              <p className="rounded-md border border-slate-200 bg-white px-3 py-2 text-xs text-slate-600">
                {statusMessage}
              </p>
            )}
          </div>

          <div className="flex-1 overflow-y-auto px-4 pb-4">
            <h3 className="text-xs font-semibold text-slate-900 uppercase tracking-wider mb-3">
              Uploaded Files ({files.length})
            </h3>

            {files.length === 0 ? (
              <div className="text-center py-8 text-sm text-slate-500">No files uploaded yet.</div>
            ) : (
              <ul className="space-y-2">
                {files.map((file) => (
                  <li
                    key={file.id}
                    className="flex items-start gap-2 p-3 bg-white rounded-md border border-slate-200 shadow-sm"
                  >
                    <FileText className="h-4 w-4 text-blue-500 mt-0.5 shrink-0" />
                    <div className="min-w-0 flex-1">
                      <span className="block text-sm text-slate-700 truncate" title={file.name}>
                        {file.name}
                      </span>
                      <div className="mt-1 flex flex-wrap items-center gap-2 text-[10px] text-slate-500">
                        {file.ingestionJobId && <span>Job {file.ingestionJobId}</span>}
                        {file.updatedAt && <span>Updated {formatRelativeStatusTime(file.updatedAt)}</span>}
                      </div>
                      {file.errorMessage && (
                        <p className="mt-1 line-clamp-2 text-[11px] text-red-600" title={file.errorMessage}>
                          {file.errorMessage}
                        </p>
                      )}
                    </div>
                    <Badge variant="outline" className={getStatusBadgeClass(file.status)}>
                      {file.status}
                    </Badge>
                    {canManageDocuments && (
                      <Button
                        variant="ghost"
                        size="icon-xs"
                        aria-label={`Delete ${file.name}`}
                        title="Delete document"
                        onClick={() => void handleDeleteFile(file)}
                        disabled={deletingFileId === file.id}
                      >
                        {deletingFileId === file.id ? (
                          <Loader2 className="h-3 w-3 animate-spin" />
                        ) : (
                          <Trash2 className="h-3 w-3 text-red-600" />
                        )}
                      </Button>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>

        <div className="w-full md:w-[70%] flex flex-col h-full bg-white relative">
          <div className="flex-1 overflow-y-auto p-4 md:p-6 space-y-6">
            {!hasReadyDocument && (
              <div className="rounded-md border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
                {files.length === 0
                  ? 'Upload a PDF or DOCX to start. The system will sync it to Bedrock automatically.'
                  : processingCount > 0
                    ? 'Document sync is still running. Status refreshes automatically every 5 seconds.'
                    : 'No ready document is available for chat. Check error details or upload another file.'}
              </div>
            )}

            {messages.map((msg) => (
              <div
                key={msg.id}
                className={`flex gap-4 ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                {msg.role === 'ai' && (
                  <div className="h-8 w-8 rounded-full bg-blue-100 flex items-center justify-center shrink-0 border border-blue-200">
                    <Bot className="h-5 w-5 text-blue-600" />
                  </div>
                )}

                <div className={`flex flex-col gap-1 max-w-[80%] ${msg.role === 'user' ? 'items-end' : 'items-start'}`}>
                  <div
                    className={`px-4 py-3 rounded-2xl text-sm ${
                      msg.role === 'user'
                        ? 'bg-blue-600 text-white rounded-tr-sm'
                        : 'bg-slate-100 text-slate-900 rounded-tl-sm'
                    }`}
                  >
                    {msg.content}
                  </div>

                  {msg.source && (
                    <Badge variant="secondary" className="mt-1 text-xs font-normal text-slate-500 bg-slate-100/50">
                      Source: {msg.source}
                    </Badge>
                  )}
                </div>

                {msg.role === 'user' && (
                  <div className="h-8 w-8 rounded-full bg-slate-200 flex items-center justify-center shrink-0 border border-slate-300">
                    <User className="h-5 w-5 text-slate-600" />
                  </div>
                )}
              </div>
            ))}

            {isThinking && (
              <div className="flex gap-4 justify-start">
                <div className="h-8 w-8 rounded-full bg-blue-100 flex items-center justify-center shrink-0 border border-blue-200">
                  <Bot className="h-5 w-5 text-blue-600" />
                </div>
                <div className="px-4 py-3 rounded-2xl text-sm bg-slate-100 text-slate-900 rounded-tl-sm flex items-center gap-2">
                  <span className="h-2 w-2 bg-slate-400 rounded-full animate-bounce [animation-delay:-0.3s]" />
                  <span className="h-2 w-2 bg-slate-400 rounded-full animate-bounce [animation-delay:-0.15s]" />
                  <span className="h-2 w-2 bg-slate-400 rounded-full animate-bounce" />
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>

          <div className="p-4 bg-white border-t border-slate-200">
            <form onSubmit={handleSendMessage} className="max-w-3xl mx-auto relative flex items-center">
              <Input
                value={inputValue}
                onChange={(event: React.ChangeEvent<HTMLInputElement>) => setInputValue(event.target.value)}
                placeholder={chatPlaceholder}
                className="pr-12 py-6 rounded-full border-slate-300 shadow-sm focus-visible:ring-blue-500"
                disabled={chatDisabled}
              />
              <Button
                type="submit"
                size="icon"
                className="absolute right-1.5 h-9 w-9 rounded-full bg-blue-600 hover:bg-blue-700"
                disabled={!inputValue.trim() || chatDisabled}
              >
                <Send className="h-4 w-4 text-white" />
              </Button>
            </form>
            <div className="text-center mt-2">
              <p className="text-[10px] text-slate-400">AI can make mistakes. Check important information.</p>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
