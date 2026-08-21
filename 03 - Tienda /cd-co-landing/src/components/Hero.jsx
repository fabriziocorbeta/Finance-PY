import { motion } from 'framer-motion'
import { ChevronDown } from 'lucide-react'

export default function Hero() {
  return (
    <section
      id="hero"
      className="relative min-h-screen flex flex-col items-center justify-center px-4 pt-20 overflow-hidden"
    >
      {/* Subtle radial glow */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_rgba(255,255,255,0.03)_0%,_transparent_70%)]" />

      <motion.div
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, ease: 'easeOut' }}
        className="relative z-10 text-center max-w-3xl mx-auto"
      >
        <p className="text-xs sm:text-sm tracking-[0.3em] uppercase text-platinum mb-6 font-light">
          Relojes originales &mdash; Paraguay
        </p>

        <h1 className="font-serif text-5xl sm:text-6xl lg:text-8xl font-semibold text-accent leading-[0.95] mb-6">
          CD & Co.
        </h1>

        <div className="w-12 h-px bg-border mx-auto mb-6" />

        <p className="text-base sm:text-lg text-platinum font-light leading-relaxed max-w-xl mx-auto mb-10">
          Casio &middot; Seiko &middot; Citizen
          <br />
          <span className="text-sm text-platinum/70">
            Distribuidor autorizado. Garantía oficial. Envíos a todo el país.
          </span>
        </p>

        <a
          href="#catalogo"
          className="inline-flex items-center gap-2 px-8 py-3 border border-accent/20 text-sm uppercase tracking-widest text-bone hover:bg-accent hover:text-carbon transition-all duration-500"
        >
          Ver Colección
        </a>
      </motion.div>

      {/* Scroll indicator */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.5, duration: 1 }}
        className="absolute bottom-8 left-1/2 -translate-x-1/2"
      >
        <motion.div
          animate={{ y: [0, 8, 0] }}
          transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
        >
          <ChevronDown className="w-5 h-5 text-platinum/40" />
        </motion.div>
      </motion.div>
    </section>
  )
}
