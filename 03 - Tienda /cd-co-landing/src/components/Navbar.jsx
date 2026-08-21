import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Menu, X, Watch } from 'lucide-react'

const navLinks = [
  { label: 'Inicio', href: '#hero' },
  { label: 'Catálogo', href: '#catalogo' },
  { label: 'Marcas', href: '#catalogo' },
  { label: 'Contacto', href: '#contacto' },
]

export default function Navbar() {
  const [open, setOpen] = useState(false)

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 bg-carbon/80 backdrop-blur-xl border-b border-border">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16 lg:h-20">
          {/* Logo */}
          <a href="#hero" className="flex items-center gap-2 group">
            <Watch className="w-6 h-6 text-bone group-hover:text-accent transition-colors" strokeWidth={1.5} />
            <span className="font-serif text-xl lg:text-2xl font-semibold tracking-tight text-accent">
              CD & Co.
            </span>
          </a>

          {/* Desktop links */}
          <div className="hidden md:flex items-center gap-8">
            {navLinks.map(link => (
              <a
                key={link.label}
                href={link.href}
                className="text-sm font-light text-platinum hover:text-accent transition-colors duration-300 tracking-wide uppercase"
              >
                {link.label}
              </a>
            ))}
          </div>

          {/* Mobile toggle */}
          <button
            onClick={() => setOpen(!open)}
            className="md:hidden p-2 text-bone"
            aria-label="Toggle menu"
          >
            {open ? <X size={22} /> : <Menu size={22} />}
          </button>
        </div>
      </div>

      {/* Mobile menu */}
      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3, ease: 'easeInOut' }}
            className="md:hidden overflow-hidden bg-carbon border-b border-border"
          >
            <div className="px-4 py-4 flex flex-col gap-4">
              {navLinks.map(link => (
                <a
                  key={link.label}
                  href={link.href}
                  onClick={() => setOpen(false)}
                  className="text-sm font-light text-platinum hover:text-accent transition-colors tracking-wide uppercase py-2"
                >
                  {link.label}
                </a>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </nav>
  )
}
