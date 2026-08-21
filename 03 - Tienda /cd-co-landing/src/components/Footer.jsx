import { Watch, MapPin, Phone, AtSign } from 'lucide-react'

export default function Footer() {
  return (
    <footer id="contacto" className="border-t border-border bg-card/50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-10">
          {/* Brand */}
          <div>
            <div className="flex items-center gap-2 mb-4">
              <Watch className="w-5 h-5 text-bone" strokeWidth={1.5} />
              <span className="font-serif text-xl font-semibold text-accent">CD & Co.</span>
            </div>
            <p className="text-sm text-platinum/70 leading-relaxed font-light">
              Distribuidor autorizado de relojes Casio, Seiko y Citizen en Paraguay.
              Garantía oficial en todos nuestros productos.
            </p>
          </div>

          {/* Contact */}
          <div>
            <h4 className="text-xs uppercase tracking-[0.2em] text-platinum mb-4">Contacto</h4>
            <ul className="space-y-3">
              <li className="flex items-center gap-2 text-sm text-platinum/70">
                <MapPin size={14} className="shrink-0" />
                Asunción, Paraguay
              </li>
              <li className="flex items-center gap-2 text-sm text-platinum/70">
                <Phone size={14} className="shrink-0" />
                +595 981 XXXXXX
              </li>
              <li className="flex items-center gap-2 text-sm text-platinum/70">
                <AtSign size={14} className="shrink-0" />
                @cdandco.py
              </li>
            </ul>
          </div>

          {/* Links */}
          <div>
            <h4 className="text-xs uppercase tracking-[0.2em] text-platinum mb-4">Navegación</h4>
            <ul className="space-y-2">
              {['Inicio', 'Catálogo', 'Contacto'].map(item => (
                <li key={item}>
                  <a
                    href={`#${item === 'Inicio' ? 'hero' : item === 'Catálogo' ? 'catalogo' : 'contacto'}`}
                    className="text-sm text-platinum/70 hover:text-accent transition-colors font-light"
                  >
                    {item}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="mt-12 pt-6 border-t border-border text-center">
          <p className="text-xs text-platinum/40 font-light">
            &copy; {new Date().getFullYear()} CD & Co. Todos los derechos reservados.
          </p>
        </div>
      </div>
    </footer>
  )
}
