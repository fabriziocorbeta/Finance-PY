import { useState } from 'react'
import { motion } from 'framer-motion'
import { products, brands } from '../data/products'
import ProductCard from './ProductCard'

export default function Catalog() {
  const [activeBrand, setActiveBrand] = useState('Todos')

  const filtered = activeBrand === 'Todos'
    ? products
    : products.filter(p => p.brand === activeBrand)

  return (
    <section id="catalogo" className="py-20 sm:py-28 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="text-center mb-12 sm:mb-16">
        <p className="text-xs tracking-[0.3em] uppercase text-platinum mb-3 font-light">
          Nuestra Selección
        </p>
        <h2 className="font-serif text-3xl sm:text-4xl lg:text-5xl text-accent font-semibold">
          Catálogo
        </h2>
      </div>

      {/* Brand filter */}
      <div className="flex flex-wrap justify-center gap-2 sm:gap-3 mb-10 sm:mb-14">
        {brands.map(brand => (
          <button
            key={brand}
            onClick={() => setActiveBrand(brand)}
            className={`px-4 py-2 text-xs uppercase tracking-widest border transition-all duration-300 cursor-pointer ${
              activeBrand === brand
                ? 'bg-accent text-carbon border-accent'
                : 'bg-transparent text-platinum border-border hover:border-platinum/40 hover:text-bone'
            }`}
          >
            {brand}
          </button>
        ))}
      </div>

      {/* Product grid: 1 col mobile, 2 tablet, 4 desktop */}
      <motion.div
        layout
        className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-5 lg:gap-6"
      >
        {filtered.map((product, i) => (
          <ProductCard key={product.id} product={product} index={i} />
        ))}
      </motion.div>
    </section>
  )
}
