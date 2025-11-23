import { HashRouter as Router, Route, Routes, NavLink } from 'react-router-dom';
import reactLogo from './assets/react.svg';
import viteLogo from '/vite.svg';
import './App.css';
import Home from './pages/Home';
import Products from './pages/Products';
import Accounts from './pages/Accounts';
import Groups from './pages/Groups';
import Profile from './pages/Profile';
import { AuthButton } from './components/AuthButton';

function App() {
  return (
    <Router>
      <div className="app">
        <header className="header">
          <div className="header-content">
            <div className="logo-section">
              <a href="https://vite.dev" target="_blank">
                <img src={viteLogo} alt="Vite logo" />
              </a>
              <a href="https://react.dev" target="_blank">
                <img src={reactLogo} alt="React logo" />
              </a>
              <h1>My Power Pages SPA</h1>
            </div>
            <nav className="navigation">
              <NavLink to="/" end>Home</NavLink>
              <NavLink to="/products">Products</NavLink>
              <NavLink to="/accounts">Accounts</NavLink>
              <NavLink to="/groups">Groups</NavLink>
              <NavLink to="/profile">Profile</NavLink>
              <AuthButton />
            </nav>
          </div>
        </header>

        <main className="main-content">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/products" element={<Products />} />
            <Route path="/accounts" element={<Accounts />} />
            <Route path="/groups" element={<Groups />} />
            <Route path="/profile" element={<Profile />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;