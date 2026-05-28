import { useEffect, useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { Building2, KeyRound, Loader2, ShieldCheck, UserPlus, Users } from 'lucide-react';

import { Button } from '../components/ui/button';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { clearSession, getApiUrl } from '../lib/api';

interface LoginResponse {
  token: string;
  user: {
    email: string;
    tenant_id: string;
    company_name: string;
    role: 'company_admin' | 'member';
  };
  error?: string;
}

interface DemoAccount {
  email: string;
  tenant_id: string;
  company_name: string;
  role: 'company_admin' | 'member';
}

const fallbackDemoAccounts: DemoAccount[] = [
  { email: 'admin@companya.test', tenant_id: 'company_a', company_name: 'Company A', role: 'company_admin' },
  { email: 'member@companya.test', tenant_id: 'company_a', company_name: 'Company A', role: 'member' },
  { email: 'admin@companyb.test', tenant_id: 'company_b', company_name: 'Company B', role: 'company_admin' },
  { email: 'member@companyb.test', tenant_id: 'company_b', company_name: 'Company B', role: 'member' },
];

export default function LoginPage() {
  const [email, setEmail] = useState('admin@companya.test');
  const [password, setPassword] = useState('123456');
  const [loading, setLoading] = useState(false);
  const [accounts, setAccounts] = useState<DemoAccount[]>(fallbackDemoAccounts);
  const [error, setError] = useState('');
  const [companyName, setCompanyName] = useState('');
  const [adminEmail, setAdminEmail] = useState('');
  const [adminPassword, setAdminPassword] = useState('');
  const [registerLoading, setRegisterLoading] = useState(false);
  const [registerError, setRegisterError] = useState('');
  const navigate = useNavigate();

  const persistSession = (data: LoginResponse) => {
    clearSession();
    localStorage.setItem('auth_token', data.token);
    localStorage.setItem('tenant_id', data.user.tenant_id);
    localStorage.setItem('company_name', data.user.company_name);
    localStorage.setItem('user_role', data.user.role);
    localStorage.setItem('user_email', data.user.email);
    navigate('/knowledge-bases');
  };

  useEffect(() => {
    const loadAccounts = async () => {
      const apiUrl = getApiUrl();
      if (!apiUrl) return;

      try {
        const response = await fetch(`${apiUrl}/auth/accounts`);
        if (!response.ok) return;
        const data = (await response.json()) as { accounts?: DemoAccount[] };
        if (data.accounts?.length) {
          setAccounts(data.accounts);
          setEmail(data.accounts[0].email);
        }
      } catch (err) {
        console.warn('Could not load demo accounts from API', err);
      }
    };

    void loadAccounts();
  }, []);

  const handleLogin = async (event: FormEvent) => {
    event.preventDefault();
    setError('');
    setLoading(true);

    try {
      const apiUrl = getApiUrl();
      if (!apiUrl) throw new Error('VITE_API_URL is not configured.');

      const response = await fetch(`${apiUrl}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      const data = (await response.json()) as LoginResponse;

      if (!response.ok) {
        throw new Error(data.error || 'Invalid email or password');
      }

      persistSession(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not sign in.');
    } finally {
      setLoading(false);
    }
  };

  const handleRegisterCompany = async (event: FormEvent) => {
    event.preventDefault();
    setRegisterError('');
    setRegisterLoading(true);

    try {
      const apiUrl = getApiUrl();
      if (!apiUrl) throw new Error('VITE_API_URL is not configured.');

      const response = await fetch(`${apiUrl}/companies/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          company_name: companyName,
          admin_email: adminEmail,
          admin_password: adminPassword,
        }),
      });
      const data = (await response.json()) as LoginResponse;

      if (!response.ok) {
        throw new Error(data.error || 'Could not register company');
      }

      persistSession(data);
    } catch (err) {
      setRegisterError(err instanceof Error ? err.message : 'Could not register company.');
    } finally {
      setRegisterLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50 p-4">
      <Card className="w-full max-w-lg border-slate-200 shadow-xl">
        <CardHeader className="space-y-3 pb-6">
          <div className="flex items-center gap-3">
            <div className="h-11 w-11 rounded-lg bg-slate-900 flex items-center justify-center text-white font-extrabold text-xl">
              D
            </div>
            <div>
              <CardTitle className="text-2xl font-bold tracking-tight">DocHub AI</CardTitle>
              <CardDescription>Sign in with a company account</CardDescription>
            </div>
          </div>
        </CardHeader>

        <form onSubmit={handleLogin}>
          <CardContent className="space-y-5">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {accounts.map((account) => (
                <Button
                  key={account.email}
                  type="button"
                  variant={email === account.email ? 'secondary' : 'outline'}
                  className="justify-start gap-2 h-auto py-3"
                  onClick={() => {
                    setEmail(account.email);
                    setPassword('123456');
                    setError('');
                  }}
                >
                  {account.role === 'company_admin' ? (
                    <ShieldCheck className="h-4 w-4 text-emerald-600" />
                  ) : (
                    <Users className="h-4 w-4 text-blue-600" />
                  )}
                  <span className="text-left text-xs leading-tight">
                    {account.company_name} {account.role === 'company_admin' ? 'Admin' : 'Member'}
                  </span>
                </Button>
              ))}
            </div>

            <div className="space-y-2">
              <label htmlFor="email" className="text-sm font-medium">
                Email
              </label>
              <div className="relative">
                <Building2 className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                <Input
                  id="email"
                  type="email"
                  className="pl-9"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  required
                />
              </div>
            </div>

            <div className="space-y-2">
              <label htmlFor="password" className="text-sm font-medium">
                Password
              </label>
              <div className="relative">
                <KeyRound className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                <Input
                  id="password"
                  type="password"
                  className="pl-9"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  required
                />
              </div>
              {error && <p className="text-sm text-red-600">{error}</p>}
            </div>
          </CardContent>

          <CardFooter>
            <Button className="w-full" type="submit" disabled={loading}>
              {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Sign In
            </Button>
          </CardFooter>
        </form>

        <div className="border-t border-slate-200 px-6 py-5">
          <form onSubmit={handleRegisterCompany} className="space-y-4">
            <div className="flex items-center gap-2">
              <UserPlus className="h-4 w-4 text-slate-600" />
              <h2 className="text-sm font-semibold text-slate-900">Register a new company</h2>
            </div>
            <div className="grid gap-3 sm:grid-cols-2">
              <Input
                placeholder="Company name"
                value={companyName}
                onChange={(event) => {
                  setCompanyName(event.target.value);
                  setRegisterError('');
                }}
                required
              />
              <Input
                type="email"
                placeholder="Admin email"
                value={adminEmail}
                onChange={(event) => {
                  setAdminEmail(event.target.value);
                  setRegisterError('');
                }}
                required
              />
            </div>
            <Input
              type="password"
              placeholder="Admin password, min 6 characters"
              value={adminPassword}
              minLength={6}
              onChange={(event) => {
                setAdminPassword(event.target.value);
                setRegisterError('');
              }}
              required
            />
            {registerError && <p className="text-sm text-red-600">{registerError}</p>}
            <Button
              className="w-full"
              type="submit"
              variant="outline"
              disabled={registerLoading || !companyName.trim() || !adminEmail.trim() || adminPassword.length < 6}
            >
              {registerLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Create Company Admin
            </Button>
          </form>
        </div>
      </Card>
    </div>
  );
}
