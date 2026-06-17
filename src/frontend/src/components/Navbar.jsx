import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

export default function Navbar() {
  const { player, logout } = useAuth()
  const navigate = useNavigate()

  const handleLogout = async () => {
    await logout()
    navigate('/login')
  }

  return (
    <nav className="navbar">
      <Link to="/" className="navbar-brand">🎮 Gathel</Link>
      <div className="navbar-links">
        <Link to="/">Dashboard</Link>
        <Link to="/propositions">Proposiciones</Link>
        <Link to="/results">Resultados</Link>
      </div>
      <div className="navbar-user">
        <span>{player?.display_name || player?.username}</span>
        <button onClick={handleLogout}>Salir</button>
      </div>
    </nav>
  )
}
