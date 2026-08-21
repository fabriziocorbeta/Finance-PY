import { signOut } from '../_actions/auth';
import { LogOut } from 'lucide-react';

export function SignOutButton() {
  return (
    <form action={signOut}>
      <button
        type="submit"
        className="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm text-slate-300 hover:bg-white/5 hover:text-white transition"
        aria-label="Cerrar sesión"
      >
        <LogOut size={15} /> Cerrar sesión
      </button>
    </form>
  );
}
