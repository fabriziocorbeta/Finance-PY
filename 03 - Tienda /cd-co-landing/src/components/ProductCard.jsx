import { motion } from 'framer-motion'
import { MessageCircle } from 'lucide-react'
import { formatPrice, getWhatsAppUrl } from '../data/products'

export default function ProductCard({ product, index }) {
  return (
    <motion.article
      initial={{ opacity: 0, y: 40 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-50px' }}
      transition={{ duration: 0.5, delay: index * 0.08 }}
      className="group bg-card border border-border rounded-sm overflow-hidden hover:border-platinum/30 transition-colors duration-500"
    >
      {/* Image */}
      <div className="relative aspect-square overflow-hidden bg-carbon">
        <img
          src={product.image}
          alt={product.name}
          loading="lazy"
          onError={(e) => {
            e.currentTarget.src = `https://placehold.co/600x600/121212/8a8a8a?text=${encodeURIComponent(product.brand)}`
          }}
          className="w-full h-full object-cover transition-transform duration-700 ease-out group-hover:scale-105"
        />
        {/* Hover overlay */}
        <div className="absolute inset-0 bg-carbon/0 group-hover:bg-carbon/20 transition-colors duration-500" />

        {/* Brand badge */}
        <span className="absolute top-3 left-3 text-[10px] uppercase tracking-[0.2em] text-platinum/80 bg-carbon/70 backdrop-blur-sm px-2.5 py-1">
          {product.brand}
        </span>
      </div>

      {/* Info */}
      <div className="p-4 sm:p-5">
        <h3 className="font-serif text-base sm:text-lg text-bone mb-1 leading-snug">
          {product.name}
        </h3>
        <p className="text-xs text-platinum/60 mb-3 line-clamp-2">
          {product.description}
        </p>

        <div className="flex items-end justify-between gap-2">
          <span className="text-lg sm:text-xl font-sans font-medium text-accent tracking-tight">
            {formatPrice(product.price)}
          </span>

          <a
            href={getWhatsAppUrl(product.name)}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 px-4 py-2 bg-accent text-carbon text-xs font-medium uppercase tracking-wider hover:bg-bone transition-colors duration-300"
          >
            <MessageCircle size={14} />
            Comprar
          </a>
        </div>
      </div>
    </motion.article>
  )
}
