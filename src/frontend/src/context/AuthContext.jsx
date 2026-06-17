import { createContext, useContext, useState } from 'react'
import api from '../api/client'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [player, setPlayer] = useState(() => {
    const saved = localStorage.getItem('player')
    return saved ? JSON.parse(saved) : null
  })

  const login = async (username, password) => {
    const { data } = await api.post('/auth/login', { username, password })
    localStorage.setItem('token', data.access_token)
    localStorage.setItem('player', JSON.stringify(data))
    setPlayer(data)
    return data
  }

  const logout = async () => {
    await api.post('/auth/logout').catch(() => {})
    localStorage.removeItem('token')
    localStorage.removeItem('player')
    setPlayer(null)
  }

  return (
    <AuthContext.Provider value={{ player, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
