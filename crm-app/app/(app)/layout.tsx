import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import {
  LayoutDashboard, Users, KanbanSquare, MessageSquare, Settings,
  Bell, Search, Plug
} from 'lucide-react';
import { SignOutButton } from './_components/sign-out';

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data: profile } = await supabase
    .from('profiles').select('full_name, role, org_id, organizations(name)').eq('id', user.id).single();
  const orgName = (profile?.organizations as { name: string } | null)?.name ?? 'Organización';

  return (
    <div className="flex min-h-dvh">
      <aside className="w-60 bg-[#0A0F1E] text-slate-300 fixed inset-y-0 left-0 flex flex-col">
        <div className="px-4 py-5 border-b border-white/5 flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-lg bg-brand-gradient flex items-center justify-center text-white font-bold text-sm">N</div>
          <div className="min-w-0">
            <p className="text-white font-semibold text-sm leading-tight truncate">Nexus CRM</p>
            <p className="text-[10px] text-slate-500 truncate">{orgName}</p>
          </div>
        </div>

        <nav className="flex-1 px-2 py-3 space-y-0.5 overflow-y-auto">
          <NavItem href="/dashboard" icon={<LayoutDashboard size={17} />}>Dashboard</NavItem>
          <NavItem href="/contactos" icon={<Users size={17} />}>Contactos</NavItem>
          <NavItem href="/pipeline" icon={<KanbanSquare size={17} />}>Pipeline</NavItem>

          <p className="text-[10px] uppercase tracking-wider text-slate-500 px-3 pt-5 pb-2">Canales</p>
          <NavItem href="/mensajeria" icon={<MessageSquare size={17} />} disabled>
            Mensajería <span className="ml-auto text-[9px] bg-amber-500/20 text-amber-400 px-1.5 py-0.5 rounded">F2</span>
          </NavItem>
          <NavItem href="/integraciones" icon={<Plug size={17} />}>Integraciones</NavItem>

          <p className="text-[10px] uppercase tracking-wider text-slate-500 px-3 pt-5 pb-2">Sistema</p>
          <NavItem href="/ajustes" icon={<Settings size={17} />} disabled>Ajustes</NavItem>
        </nav>

        <div className="px-3 py-3 border-t border-white/5 space-y-1">
          <div className="flex items-center gap-2.5 px-2 py-2 rounded-lg hover:bg-white/5">
            <div className="w-8 h-8 rounded-full bg-brand-gradient flex items-center justify-center text-white text-xs font-semibold shrink-0">
              {(profile?.full_name ?? user.email ?? 'U').slice(0,2).toUpperCase()}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-xs text-white truncate">{profile?.full_name ?? user.email}</p>
              <p className="text-[10px] text-slate-500 capitalize">{profile?.role ?? 'member'}</p>
            </div>
          </div>
          <SignOutButton />
        </div>
      </aside>

      <main className="flex-1 ml-60 min-h-dvh">
        <header className="h-14 bg-surface border-b border-border flex items-center px-5 sticky top-0 z-10">
          <div className="flex items-center gap-2 px-3 py-1.5 bg-surface2 border border-border rounded-lg text-sm text-text2 w-72">
            <Search size={14} />
            <input className="bg-transparent outline-none flex-1 text-text1" placeholder="Buscar contactos, deals…" aria-label="Buscar" />
            <kbd className="text-[10px] text-text3 border border-border rounded px-1">⌘K</kbd>
          </div>
          <div className="ml-auto flex items-center gap-2">
            <button className="w-9 h-9 rounded-lg border border-border hover:bg-surface2 flex items-center justify-center text-text2" aria-label="Notificaciones">
              <Bell size={15} />
            </button>
          </div>
        </header>
        <div className="p-6">{children}</div>
      </main>
    </div>
  );
}

function NavItem({ href, icon, children, disabled }: { href: string; icon: React.ReactNode; children: React.ReactNode; disabled?: boolean }) {
  const cls = 'flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm transition';
  if (disabled) return <span className={`${cls} text-slate-600 cursor-not-allowed`}>{icon}{children}</span>;
  return <Link href={href} className={`${cls} text-slate-300 hover:bg-white/5 hover:text-white`}>{icon}{children}</Link>;
}
