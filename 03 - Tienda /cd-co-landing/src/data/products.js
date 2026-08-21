const WHATSAPP_NUMBER = '595981XXXXXX'

function buildWhatsAppUrl(productName) {
  const message = `Hola CD & Co, me interesa el modelo ${productName}`
  return `https://wa.me/${WHATSAPP_NUMBER}?text=${encodeURIComponent(message)}`
}

export const products = [
  {
    id: 1,
    name: 'Casio Vintage A168WA-1',
    brand: 'Casio',
    category: 'Vintage',
    price: 250000,
    image: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&h=600&fit=crop&q=80',
    description: 'El icónico reloj digital retro en acero inoxidable.',
  },
  {
    id: 2,
    name: 'Casio G-Shock GA-2100-1A1',
    brand: 'Casio',
    category: 'G-Shock',
    price: 890000,
    image: 'https://images.unsplash.com/photo-1614164185128-e4ec99c436d7?w=600&h=600&fit=crop&q=80',
    description: 'Resistencia extrema con diseño Carbon Core Guard.',
  },
  {
    id: 3,
    name: 'Seiko Presage SRPD37J1',
    brand: 'Seiko',
    category: 'Automático',
    price: 2450000,
    image: 'https://images.unsplash.com/photo-1587836374828-4dbafa94cf0e?w=600&h=600&fit=crop&q=80',
    description: 'Movimiento automático 4R35. Cristal Hardlex. Estilo cocktail.',
  },
  {
    id: 4,
    name: 'Seiko 5 Sports SRPD55K1',
    brand: 'Seiko',
    category: 'Deportivo',
    price: 1350000,
    image: 'https://images.unsplash.com/photo-1524592094714-0f0654e20314?w=600&h=600&fit=crop&q=80',
    description: 'Automático deportivo con bisel giratorio y 100m WR.',
  },
  {
    id: 5,
    name: 'Citizen Eco-Drive BM7251-53L',
    brand: 'Citizen',
    category: 'Eco-Drive',
    price: 1680000,
    image: 'https://images.unsplash.com/photo-1522312346375-d1a52e2b99b3?w=600&h=600&fit=crop&q=80',
    description: 'Energía solar infinita. Esfera azul con acero plateado.',
  },
  {
    id: 6,
    name: 'Casio Vintage A700W-1A',
    brand: 'Casio',
    category: 'Vintage',
    price: 320000,
    image: 'https://images.unsplash.com/photo-1533139502658-0198f920d8e8?w=600&h=600&fit=crop&q=80',
    description: 'Ultra-delgado. El slim vintage más elegante de Casio.',
  },
  {
    id: 7,
    name: 'Citizen Promaster BN0150-28E',
    brand: 'Citizen',
    category: 'Diver',
    price: 1950000,
    image: 'https://images.unsplash.com/photo-1509048191080-d2984bad6ae5?w=600&h=600&fit=crop&q=80',
    description: 'Diver profesional Eco-Drive. 200m de resistencia al agua.',
  },
  {
    id: 8,
    name: 'Casio G-Shock DW-5600E-1V',
    brand: 'Casio',
    category: 'G-Shock',
    price: 490000,
    image: 'https://images.unsplash.com/photo-1585123334904-845d60e97b29?w=600&h=600&fit=crop&q=80',
    description: 'El G-Shock clásico cuadrado. Resistente a todo.',
  },
]

export function getWhatsAppUrl(productName) {
  return buildWhatsAppUrl(productName)
}

export function formatPrice(price) {
  return new Intl.NumberFormat('es-PY').format(price) + ' Gs.'
}

export const brands = ['Todos', ...new Set(products.map(p => p.brand))]
