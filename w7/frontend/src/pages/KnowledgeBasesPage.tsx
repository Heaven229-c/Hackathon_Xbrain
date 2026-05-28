import { useEffect, useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button } from '../components/ui/button';
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from '../components/ui/card';
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '../components/ui/dialog';
import { Input } from '../components/ui/input';
import { FolderOpen, Loader2, Plus, ShieldCheck, Trash2, UserPlus, Users } from 'lucide-react';
import Header from '../components/layout/Header';
import { getApiUrl, getAuthToken, getCompanyName, getTenantId, getUserEmail, getUserRole, tenantFetch } from '../lib/api';

interface KnowledgeBase {
  id: string;
  name: string;
  createdAt: string;
  tenantId: string;
}

interface WorkspaceResponseItem {
  workspace_id: string;
  display_name?: string;
  tenant_name: string;
  created_at: string;
}

interface CompanyUser {
  email: string;
  company_name: string;
  tenant_id: string;
  role: 'company_admin' | 'member';
  created_at?: string;
}

export default function KnowledgeBasesPage() {
  const navigate = useNavigate();
  const [tenantId] = useState<string | null>(() => getTenantId());
  const [authToken] = useState<string | null>(() => getAuthToken());
  const [companyName] = useState<string>(() => getCompanyName() ?? 'Company');
  const [userRole] = useState<string | null>(() => getUserRole());
  const [currentUserEmail] = useState<string | null>(() => getUserEmail());
  const [kbs, setKbs] = useState<KnowledgeBase[]>([]);
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [newKbName, setNewKbName] = useState('');
  const [createError, setCreateError] = useState<string | null>(null);
  const [deletingKbId, setDeletingKbId] = useState<string | null>(null);
  const [companyUsers, setCompanyUsers] = useState<CompanyUser[]>([]);
  const [newUserEmail, setNewUserEmail] = useState('');
  const [newUserPassword, setNewUserPassword] = useState('123456');
  const [newUserRole, setNewUserRole] = useState<'member' | 'company_admin'>('member');
  const [isCreatingUser, setIsCreatingUser] = useState(false);
  const [userCreateError, setUserCreateError] = useState<string | null>(null);
  const [deletingUserEmail, setDeletingUserEmail] = useState<string | null>(null);
  const [userDeleteError, setUserDeleteError] = useState<string | null>(null);

  useEffect(() => {
    if (!tenantId || !authToken) {
      navigate('/');
      return;
    }

    const fetchWorkspaces = async () => {
      try {
        const apiUrl = getApiUrl();
        if (!apiUrl) return;
        
        const response = await tenantFetch(`${apiUrl}/workspaces`);
        if (response.ok) {
          const data = await response.json();
          const tenantKbs = data.workspaces
            .map((ws: WorkspaceResponseItem) => ({
              id: ws.workspace_id,
              name: ws.display_name || ws.workspace_id,
              createdAt: new Date(ws.created_at).toLocaleDateString('en-GB'),
              tenantId: ws.tenant_name,
            }));
          setKbs(tenantKbs);
        }
      } catch (error) {
        console.error('Lỗi khi tải danh sách workspace:', error);
      }
    };

    const fetchCompanyUsers = async () => {
      try {
        const apiUrl = getApiUrl();
        if (!apiUrl) return;

        const response = await tenantFetch(`${apiUrl}/companies/current`);
        if (!response.ok) return;
        const data = await response.json();
        setCompanyUsers(data.users || []);
      } catch (error) {
        console.error('Failed to load company users:', error);
      }
    };

    void fetchWorkspaces();
    void fetchCompanyUsers();
  }, [authToken, navigate, tenantId]);

  const handleCreateKb = async (e: FormEvent) => {
    e.preventDefault();
    if (!newKbName.trim() || !tenantId || userRole !== 'company_admin') return;
    
    const sanitizedId = newKbName
      .trim()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/\u0111/g, 'd')
      .replace(/\u0110/g, 'd')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 63);

    if (!sanitizedId) {
      setCreateError('Please use a name with at least one letter or number.');
      return;
    }

    try {
      setCreateError(null);
      const apiUrl = getApiUrl();
      let createdWorkspace: WorkspaceResponseItem | null = null;
      if (apiUrl) {
        const response = await tenantFetch(`${apiUrl}/workspaces`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            workspace_id: sanitizedId,
            workspace_name: newKbName.trim(),
          })
        });
        if (!response.ok) {
          const error = await response.json();
          throw new Error(error.error || 'Failed to create workspace');
        }
        const data = await response.json();
        createdWorkspace = data.workspace;
      } else {
        throw new Error('VITE_API_URL is not configured.');
      }
      
      const newKb: KnowledgeBase = {
        id: createdWorkspace?.workspace_id || sanitizedId,
        name: createdWorkspace?.display_name || newKbName.trim(),
        createdAt: new Date().toLocaleDateString('en-GB'),
        tenantId,
      };
      
      setKbs((prev) => [...prev, newKb]);
      setNewKbName('');
      setIsDialogOpen(false);
    } catch (error) {
      console.error('Lỗi khi tạo workspace:', error);
      setCreateError(error instanceof Error ? error.message : 'Failed to create workspace');
    }
  };

  const handleDeleteKb = async (kb: KnowledgeBase) => {
    if (userRole !== 'company_admin') return;

    const confirmed = window.confirm(
      `Delete "${kb.name}" and all uploaded documents in this knowledge base?`
    );
    if (!confirmed) return;

    try {
      setDeletingKbId(kb.id);
      const apiUrl = getApiUrl();
      if (!apiUrl) throw new Error('VITE_API_URL is not configured.');

      const response = await tenantFetch(`${apiUrl}/workspaces?workspace_id=${encodeURIComponent(kb.id)}`, {
        method: 'DELETE',
      });
      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to delete workspace');
      }

      setKbs((prev) => prev.filter((item) => item.id !== kb.id));
    } catch (error) {
      console.error('Failed to delete workspace:', error);
      alert(error instanceof Error ? error.message : 'Failed to delete workspace');
    } finally {
      setDeletingKbId(null);
    }
  };

  const handleCreateUser = async (event: FormEvent) => {
    event.preventDefault();
    if (userRole !== 'company_admin') return;

    try {
      setIsCreatingUser(true);
      setUserCreateError(null);
      const apiUrl = getApiUrl();
      if (!apiUrl) throw new Error('VITE_API_URL is not configured.');

      const response = await tenantFetch(`${apiUrl}/companies/users`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: newUserEmail,
          password: newUserPassword,
          role: newUserRole,
        }),
      });
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error || 'Failed to create user');
      }

      setCompanyUsers((prev) => [...prev, data.user].sort((a, b) => a.email.localeCompare(b.email)));
      setNewUserEmail('');
      setNewUserPassword('123456');
      setNewUserRole('member');
    } catch (error) {
      setUserCreateError(error instanceof Error ? error.message : 'Failed to create user');
    } finally {
      setIsCreatingUser(false);
    }
  };

  const handleDeleteUser = async (user: CompanyUser) => {
    if (userRole !== 'company_admin' || user.email === currentUserEmail) return;

    const confirmed = window.confirm(`Delete user "${user.email}" from ${companyName}?`);
    if (!confirmed) return;

    try {
      setDeletingUserEmail(user.email);
      setUserDeleteError(null);
      const apiUrl = getApiUrl();
      if (!apiUrl) throw new Error('VITE_API_URL is not configured.');

      const response = await tenantFetch(`${apiUrl}/companies/users?email=${encodeURIComponent(user.email)}`, {
        method: 'DELETE',
      });
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error || 'Failed to delete user');
      }

      setCompanyUsers((prev) => prev.filter((item) => item.email !== user.email));
    } catch (error) {
      setUserDeleteError(error instanceof Error ? error.message : 'Failed to delete user');
    } finally {
      setDeletingUserEmail(null);
    }
  };

  if (!tenantId || !authToken) return null;

  const canManageKnowledgeBases = userRole === 'company_admin';

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      <Header />
      <main className="flex-1 max-w-7xl w-full mx-auto p-4 md:p-6 lg:p-8">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-8 gap-4">
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-slate-900">Knowledge Bases</h1>
            <p className="text-slate-500 mt-1">
              Welcome, {companyName} - here are your document repositories.
            </p>
          </div>
          
          {canManageKnowledgeBases && (
          <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
            {/* @ts-expect-error - base-ui DialogTrigger supports render/asChild interop in this setup */}
            <DialogTrigger asChild>
              <Button>
                <Plus className="mr-2 h-4 w-4" />
                New Knowledge Base
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px]">
              <DialogHeader>
                <DialogTitle>Create Knowledge Base</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleCreateKb}>
                <div className="grid gap-4 py-4">
                  <div className="space-y-2">
                    <label htmlFor="name" className="text-sm font-medium">
                      Name
                    </label>
                    <Input
                      id="name"
                      placeholder="e.g. Contracts 2025"
                      value={newKbName}
                      onChange={(e: React.ChangeEvent<HTMLInputElement>) => {
                        setNewKbName(e.target.value);
                        setCreateError(null);
                      }}
                      required
                    />
                    {createError && <p className="text-sm text-red-600">{createError}</p>}
                  </div>
                </div>
                <DialogFooter>
                  <Button type="submit" disabled={!newKbName.trim()}>Create</Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
          )}
        </div>

        <Card className="mb-8 border-slate-200">
          <CardHeader className="pb-3">
            <div className="flex items-center gap-2">
              <Users className="h-5 w-5 text-slate-600" />
              <CardTitle className="text-lg">Company access</CardTitle>
            </div>
          </CardHeader>
          <CardContent className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_360px]">
            <div>
              <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                {companyUsers.map((user) => (
                  <div key={user.email} className="rounded-md border border-slate-200 bg-slate-50 px-3 py-2">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2 text-sm font-medium text-slate-900">
                          {user.role === 'company_admin' ? (
                            <ShieldCheck className="h-4 w-4 shrink-0 text-emerald-600" />
                          ) : (
                            <Users className="h-4 w-4 shrink-0 text-blue-600" />
                          )}
                          <span className="truncate" title={user.email}>{user.email}</span>
                        </div>
                        <p className="mt-1 text-xs text-slate-500">
                          {user.role === 'company_admin' ? 'Company admin' : 'Member'} - {user.company_name}
                          {user.email === currentUserEmail ? ' - signed in' : ''}
                        </p>
                      </div>
                      {canManageKnowledgeBases && user.email !== currentUserEmail && (
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          className="h-8 w-8 shrink-0 text-slate-500 hover:text-red-600"
                          aria-label={`Delete ${user.email}`}
                          title="Delete user"
                          disabled={deletingUserEmail === user.email}
                          onClick={() => void handleDeleteUser(user)}
                        >
                          {deletingUserEmail === user.email ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            <Trash2 className="h-4 w-4" />
                          )}
                        </Button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
              {userDeleteError && <p className="mt-3 text-sm text-red-600">{userDeleteError}</p>}
              {companyUsers.length === 0 && (
                <p className="text-sm text-slate-500">No company users loaded yet.</p>
              )}
            </div>

            {canManageKnowledgeBases ? (
              <form onSubmit={handleCreateUser} className="rounded-md border border-slate-200 bg-white p-3 space-y-3">
                <div className="flex items-center gap-2 text-sm font-semibold text-slate-900">
                  <UserPlus className="h-4 w-4" />
                  Add demo user
                </div>
                <Input
                  type="email"
                  placeholder="new.user@company.test"
                  value={newUserEmail}
                  onChange={(event) => {
                    setNewUserEmail(event.target.value);
                    setUserCreateError(null);
                  }}
                  required
                />
                <div className="grid grid-cols-2 gap-2">
                  <Input
                    type="text"
                    value={newUserPassword}
                    onChange={(event) => setNewUserPassword(event.target.value)}
                    minLength={6}
                    required
                  />
                  <select
                    className="h-9 rounded-md border border-slate-300 bg-white px-3 text-sm"
                    value={newUserRole}
                    onChange={(event) => setNewUserRole(event.target.value as 'member' | 'company_admin')}
                  >
                    <option value="member">Member</option>
                    <option value="company_admin">Admin</option>
                  </select>
                </div>
                {userCreateError && <p className="text-sm text-red-600">{userCreateError}</p>}
                <Button type="submit" size="sm" className="w-full" disabled={isCreatingUser || !newUserEmail.trim()}>
                  {isCreatingUser && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Create user
                </Button>
              </form>
            ) : (
              <div className="rounded-md border border-slate-200 bg-white p-3 text-sm text-slate-500">
                Only company admins can create users and delete knowledge bases.
              </div>
            )}
          </CardContent>
        </Card>

        {kbs.length === 0 ? (
          <div className="text-center py-20 bg-white rounded-xl border border-dashed border-slate-300">
            <FolderOpen className="mx-auto h-12 w-12 text-slate-300" />
            <h3 className="mt-4 text-lg font-semibold text-slate-900">No Knowledge Bases</h3>
            <p className="mt-2 text-sm text-slate-500 max-w-sm mx-auto">
              You haven't created any document repositories yet. Create your first knowledge base to get started.
            </p>
            {canManageKnowledgeBases && (
              <Button onClick={() => setIsDialogOpen(true)} className="mt-6" variant="outline">
                <Plus className="mr-2 h-4 w-4" /> Create One Now
              </Button>
            )}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {kbs.map((kb) => (
              <Card key={kb.id} className="flex flex-col hover:shadow-md transition-shadow">
                <CardHeader>
                  <CardTitle className="text-xl line-clamp-1" title={kb.name}>{kb.name}</CardTitle>
                </CardHeader>
                <CardContent className="flex-1">
                  <p className="text-sm text-slate-500">
                    Created on {kb.createdAt}
                  </p>
                </CardContent>
                <CardFooter className="gap-2">
                  <Button 
                    className="flex-1" 
                    variant="secondary"
                    onClick={() => navigate(`/kb?kb_id=${kb.id}&name=${encodeURIComponent(kb.name)}`)}
                  >
                    Open Workspace
                  </Button>
                  {canManageKnowledgeBases && (
                    <Button
                      variant="destructive"
                      size="icon"
                      aria-label={`Delete ${kb.name}`}
                      title="Delete knowledge base"
                      onClick={() => void handleDeleteKb(kb)}
                      disabled={deletingKbId === kb.id}
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  )}
                </CardFooter>
              </Card>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
