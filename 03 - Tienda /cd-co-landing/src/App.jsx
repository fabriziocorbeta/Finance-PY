import Navbar from './components/Navbar'
import Hero from './components/Hero'
import Catalog from './components/Catalog'
import Footer from './components/Footer'

export default function App() {
  return (
    <div className="min-h-screen bg-carbon">
      <Navbar />
      <Hero />
      <Catalog />
      <Footer />
    </div>
  )
}
