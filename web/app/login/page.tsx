"use client";
import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { ArrowRight, Grape, Lock, Mail } from "lucide-react";
import { useApp } from "@/components/providers";

export default function LoginPage() {
  const { login, user } = useApp();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => { if (user) router.replace("/"); }, [user, router]);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      await login(email, password);
      router.replace("/");
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="login">
      <div className="login-art">
        <svg className="rows" viewBox="0 0 600 800" preserveAspectRatio="none" aria-hidden>
          {Array.from({ length: 26 }).map((_, i) => (
            <path key={i} d={`M ${-40 + i * 28} 820 C ${120 + i * 18} 520, ${200 + i * 14} 300, ${340 + i * 10} -20`} stroke="#fff" strokeWidth="1" fill="none" strokeDasharray="2 7" />
          ))}
        </svg>
        <div className="row" style={{ gap: 10, position: "relative" }}>
          <div className="brand-mark" style={{ background: "#fafafa", color: "#111" }}><Grape size={16} /></div>
          <b>Kerigma Agrícola</b>
        </div>
        <div style={{ position: "relative" }}>
          <h1>Control de producción del viñedo, de la planta al kilo.</h1>
          <p>Censo, poda, sanidad, cosecha, costos y liquidaciones por parcela y cohorte. Trazabilidad completa con mapa, fotos y bitácora.</p>
        </div>
        <div className="small" style={{ color: "#8a8a85", position: "relative" }}>Valle Central de Tarija · Campaña 1 jul – 30 jun</div>
      </div>
      <div className="login-form">
        <form onSubmit={submit}>
          <div>
            <h1>Iniciar sesión</h1>
            <p className="muted" style={{ marginTop: 4 }}>Ingrese con su correo y contraseña.</p>
          </div>
          <label className="field">
            <span>Correo</span>
            <div className="search"><Mail size={13} /><input className="input" type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} /></div>
          </label>
          <label className="field">
            <span>Contraseña</span>
            <div className="search"><Lock size={13} /><input className="input" type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} /></div>
          </label>
          {error && <div className="notice strong" role="alert">{error}</div>}
          <button className="btn primary" style={{ height: 34 }} disabled={busy}>
            {busy ? <div className="spinner" style={{ borderTopColor: "var(--accent-ink)" }} /> : <>Entrar <ArrowRight size={14} /></>}
          </button>
          <p className="faint small">Las acciones quedan registradas en la bitácora del sistema.</p>
        </form>
      </div>
    </div>
  );
}
