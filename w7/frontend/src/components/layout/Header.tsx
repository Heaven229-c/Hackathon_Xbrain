import { LogOut, ShieldCheck, UserRound } from 'lucide-react';
import { Button } from '../ui/button';
import { useNavigate } from 'react-router-dom';
import { clearSession, getCompanyName, getUserEmail, getUserRole } from '../../lib/api';

export default function Header() {
  const navigate = useNavigate();
  const companyName = getCompanyName() ?? 'Company';
  const userEmail = getUserEmail();
  const role = getUserRole();
  const roleLabel = role === 'company_admin' ? 'Admin' : 'Member';

  const handleLogout = () => {
    clearSession();
    navigate('/');
  };

  return (
    <header className="border-b bg-white">
      <div className="flex h-16 items-center px-4 md:px-6 w-full max-w-7xl mx-auto justify-between">
        <div className="flex items-center gap-2 font-bold text-xl tracking-tight text-slate-900">
          <div className="h-8 w-8 rounded-lg bg-slate-900 flex items-center justify-center text-white font-extrabold text-lg">
            D
          </div>
          DocHub AI
        </div>
        <div className="flex items-center gap-3">
          <div className="hidden sm:flex items-center gap-2 rounded-md border border-slate-200 px-3 py-1.5 text-sm text-slate-600">
            {role === 'company_admin' ? (
              <ShieldCheck className="h-4 w-4 text-emerald-600" />
            ) : (
              <UserRound className="h-4 w-4 text-blue-600" />
            )}
            <span className="font-medium text-slate-900">{companyName}</span>
            <span>{roleLabel}</span>
            {userEmail && <span className="hidden lg:inline text-slate-400">{userEmail}</span>}
          </div>
          <Button variant="ghost" size="sm" onClick={handleLogout} className="text-slate-600 hover:text-slate-900">
            <LogOut className="mr-2 h-4 w-4" />
            Sign Out
          </Button>
        </div>
      </div>
    </header>
  );
}
