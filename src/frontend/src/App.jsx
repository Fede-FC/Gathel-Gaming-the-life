import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './context/AuthContext'
import Navbar from './components/Navbar'
import Login from './pages/Login'
import Register from './pages/Register'
import Dashboard from './pages/Dashboard'
import Propositions from './pages/Propositions'
import Results from './pages/Results'

function PrivateRoute({ children }) {
  const { player } = useAuth()
  return player ? children : <Navigate to="/login" replace />
}

function Layout({ children }) {
  return (
    <>
      <Navbar />
      <main className="main-content">{children}</main>
    </>
  )
}

function AppRoutes() {
  const { player } = useAuth()
  return (
    <Routes>
      <Route path="/login" element={player ? <Navigate to="/" replace /> : <Login />} />
      <Route path="/register" element={player ? <Navigate to="/" replace /> : <Register />} />
      <Route path="/" element={<PrivateRoute><Layout><Dashboard /></Layout></PrivateRoute>} />
      <Route path="/propositions" element={<PrivateRoute><Layout><Propositions /></Layout></PrivateRoute>} />
      <Route path="/results" element={<PrivateRoute><Layout><Results /></Layout></PrivateRoute>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <AppRoutes />
      </BrowserRouter>
    </AuthProvider>
  )
}
