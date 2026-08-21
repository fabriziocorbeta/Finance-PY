import { Plug, MessageCircle, Instagram, Facebook } from 'lucide-react';

export default function IntegracionesPage() {
  return (
    <>
      <div className="mb-6">
        <h1 className="text-xl font-bold text-text1">Integraciones</h1>
        <p className="text-sm text-text3">Conecta tus canales para centralizar conversaciones</p>
      </div>

      <div className="grid grid-cols-2 gap-4 max-w-3xl">
        <IntegrationCard
          name="WhatsApp Business"
          desc="Recibe + responde mensajes vía Cloud API (gratis hasta 1k conversaciones/mes)"
          color="#25D366"
          icon={<MessageCircle size={20} className="text-white" />}
          status="not-connected"
          phase="F2"
        />
        <IntegrationCard
          name="Instagram + Facebook"
          desc="DMs IG, FB Messenger, insights de posts y seguidores"
          color="#E1306C"
          icon={<Instagram size={20} className="text-white" />}
          status="not-connected"
          phase="F3"
        />
        <IntegrationCard
          name="Facebook Page"
          desc="Mensajes, comentarios y métricas de página"
          color="#1877F2"
          icon={<Facebook size={20} className="text-white" />}
          status="not-connected"
          phase="F3"
        />
        <IntegrationCard
          name="Webhook genérico"
          desc="Recibe eventos de cualquier sistema externo"
          color="#4F46E5"
          icon={<Plug size={20} className="text-white" />}
          status="available"
          phase="F1"
        />
      </div>

      <div className="mt-8 max-w-3xl bg-amber-50 border border-amber-200 rounded-card p-4">
        <p className="text-sm font-semibold text-amber-900 mb-1">Pre-requisito crítico</p>
        <p className="text-sm text-amber-800">
          WhatsApp y Meta requieren <strong>verificación Meta Business Manager</strong> (3-5 días hábiles).
          Inicia el proceso ya en <a href="https://business.facebook.com" className="underline" target="_blank">business.facebook.com</a> aunque la app aún no esté lista.
        </p>
      </div>
    </>
  );
}

function IntegrationCard({ name, desc, color, icon, status, phase }: {
  name: string; desc: string; color: string; icon: React.ReactNode;
  status: 'connected' | 'not-connected' | 'available'; phase: string;
}) {
  return (
    <div className="bg-surface border border-border rounded-card shadow-card p-5">
      <div className="flex items-start gap-3 mb-3">
        <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0" style={{ background: color }}>
          {icon}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <h3 className="font-semibold text-text1">{name}</h3>
            <span className="text-[10px] font-semibold bg-surface2 text-text2 px-1.5 py-0.5 rounded">{phase}</span>
          </div>
          <p className="text-xs text-text3 mt-0.5 leading-snug">{desc}</p>
        </div>
      </div>
      <button
        disabled={status !== 'available'}
        className="w-full h-9 rounded-lg text-sm font-medium border border-border bg-surface hover:bg-surface2 text-text1 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {status === 'connected' ? 'Conectado ✓' : status === 'available' ? 'Configurar' : 'Próximamente'}
      </button>
    </div>
  );
}
