import React from 'react';
import { Server, Send } from 'lucide-react';
import { NavLink } from 'react-router-dom';

interface NavbarProps {
  isLoggedIn: boolean;
  onLogout: () => void;
}

export function Navbar({ isLoggedIn, onLogout }: NavbarProps) {
  const linkClass = ({ isActive }: { isActive: boolean }) => 
    `${isActive ? 'text-emerald-400' : 'hover:text-white'} transition-colors`;

  return (
    <nav className="border-b border-white/10 bg-black/50 backdrop-blur-md sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-emerald-500/10 border border-emerald-500/20 rounded flex items-center justify-center">
            <Server className="w-4 h-4 text-emerald-400" />
          </div>
          <span className="font-bold text-white tracking-wider">RBT</span>
          <span className="text-xs px-2 py-0.5 bg-white/5 rounded-full text-gray-400 border border-white/10">v0.0.2</span>
        </div>
        <div className="flex gap-4 md:gap-6 text-sm items-center flex-wrap">
          <NavLink to="/dashboard" className={linkClass}>Dashboard</NavLink>
          <NavLink to="/" className={linkClass}>Overview</NavLink>
          <NavLink to="/architecture" className={linkClass}>Architecture</NavLink>
          <NavLink to="/install" className={linkClass}>Install</NavLink>
          <a href="https://t.me/kingithub" target="_blank" rel="noopener noreferrer" className="p-2 rounded-full hover:bg-white/10 transition-colors cursor-pointer">
            <Send className="w-5 h-5 text-gray-300" />
          </a>
          {isLoggedIn && (
            <button onClick={onLogout} className="text-xs text-red-500 hover:text-red-400 border border-red-500/20 px-2 py-1 rounded bg-red-500/5 transition-colors">Logout</button>
          )}
        </div>
      </div>
    </nav>
  );
}
