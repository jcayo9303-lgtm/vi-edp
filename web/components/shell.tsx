"use client";
import { useState, type ReactNode } from "react";
import Link from "next/link";
import { usePathname, useSearchParams } from "next/navigation";
import { ChevronRight, Grape, KeyRound, LogOut, Menu, Moon } from "lucide-react";
import { NAV, ROLE_LABEL } from "@/lib/modules";
import { useApp } from "./providers";

export function Shell({ title, crumbs, actions, children, bare }: { title?: string; crumbs?: string[]; actions?: ReactNode; children: ReactNode; bare?: boolean }) {
  const { user, loading, logout, campanas, campanaId, setCampanaId, fincas, fincaId, setFincaId } = useApp();
  const pathname = usePathname();
  const sp = useSearchParams();
  const [open, setOpen] = useState(false);
  const current = pathname === "/datos" ? `/datos?t=${sp.get("t")}` : pathname;

  if (loading || !user) {
    return <div style={{ display: "grid", placeItems: "center", height: "100vh" }}><div className="spinner" /></div>;
  }
  const initials = user.nombre.split(" ").map((s) => s[0]).slice(0, 2).join("");
  const toggleTheme = () => {
    const el = document.documentElement;
    const dark = el.dataset.theme ? el.dataset.theme === "dark" : matchMedia("(prefers-color-scheme: dark)").matches;
    el.dataset.theme = dark ? "light" : "dark";
    try { localStorage.setItem("vc_theme", el.dataset.theme); } catch {}
  };

  return (
    <div className="shell">
      <aside className={`sidebar ${open ? "open" : ""}`}>
        <div className="brand">
          <div className="brand-mark"><Grape size={16} /></div>
          <div><b>Control de Viñedo</b><span>Producción de la vid · Tarija</span></div>
        </div>
        <nav>
          {NAV.map((g) => {
            const items = g.items.filter((i) => !i.roles || i.roles.includes(user.rol));
            if (!items.length) return null;
            return (
              <div className="nav-group" key={g.title}>
                <span className="upper">{g.title}</span>
                {items.map((i) => (
                  <Link key={i.href} href={i.href} className={`nav-link ${current === i.href ? "active" : ""}`} onClick={() => setOpen(false)}>
                    <i.icon size={14} strokeWidth={1.8} />
                    <span>{i.label}</span>
                  </Link>
                ))}
              </div>
            );
          })}
        </nav>
        <div className="sidebar-foot">
          <div className="user-chip">
            <div className="avatar">{initials}</div>
            <div className="grow">
              <div style={{ fontWeight: 600, fontSize: 12 }}>{user.nombre}</div>
              <div className="muted small">{ROLE_LABEL[user.rol]}</div>
            </div>
            <Link className="btn ghost sm icon" href="/cuenta" title="Cambiar contraseña" aria-label="Cambiar contraseña"><KeyRound size={13} /></Link>
            <button className="btn ghost sm icon" onClick={logout} title="Cerrar sesión" aria-label="Cerrar sesión"><LogOut size={13} /></button>
          </div>
        </div>
      </aside>
      {open && <div className="overlay" style={{ zIndex: 850 }} onClick={() => setOpen(false)} />}
      <div className="main">
        <header className="topbar">
          <button className="btn ghost icon menu-btn" onClick={() => setOpen(true)} aria-label="Menú"><Menu size={16} /></button>
          <div className="crumbs grow">
            {(crumbs ?? []).map((c) => (<span key={c} className="row" style={{ gap: 6 }}>{c}<ChevronRight size={12} /></span>))}
            <b>{title}</b>
          </div>
          <select className="select sm" style={{ width: 150 }} value={fincaId ?? ""} onChange={(e) => setFincaId(e.target.value ? Number(e.target.value) : null)} aria-label="Finca">
            <option value="">Todas las fincas</option>
            {fincas.map((f) => <option key={f.value} value={f.value}>{f.label}</option>)}
          </select>
          <select className="select sm" style={{ width: 150 }} value={campanaId ?? ""} onChange={(e) => setCampanaId(Number(e.target.value))} aria-label="Campaña">
            {campanas.map((c) => <option key={c.value} value={c.value}>Campaña {c.label}{c.estado === "cerrada" ? " · cerrada" : ""}</option>)}
          </select>
          <button className="btn ghost icon" onClick={toggleTheme} title="Tema claro / oscuro" aria-label="Cambiar tema"><Moon size={14} /></button>
        </header>
        {bare ? children : (
          <main className="content">
            {(title || actions) && (
              <div className="page-head">
                <div className="grow"><h1>{title}</h1></div>
                {actions}
              </div>
            )}
            {children}
          </main>
        )}
      </div>
    </div>
  );
}
