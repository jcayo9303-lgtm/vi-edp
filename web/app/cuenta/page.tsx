"use client";
import { useState, type FormEvent } from "react";
import { Shell } from "@/components/shell";
import { useApp, useToast } from "@/components/providers";
import { api } from "@/lib/api";
import { ROLE_LABEL } from "@/lib/modules";

export default function CuentaPage() {
  const { user } = useApp();
  const toast = useToast();
  const [actual, setActual] = useState("");
  const [nueva, setNueva] = useState("");
  const [rep, setRep] = useState("");
  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (nueva !== rep) return toast("Las contraseñas nuevas no coinciden", "warn");
    try {
      await api.post("/auth/password", { actual, nueva });
      toast("Contraseña actualizada");
      setActual(""); setNueva(""); setRep("");
    } catch (err) { toast((err as Error).message, "warn"); }
  };
  return (
    <Shell title="Mi cuenta">
      <div className="card" style={{ maxWidth: 420 }}>
        <div className="card-head"><h2>{user?.nombre}</h2><span className="sub">{user?.email} · {user && ROLE_LABEL[user.rol]}</span></div>
        <form className="card-body stack" onSubmit={submit}>
          <label className="field"><span>Contraseña actual</span><input className="input" type="password" autoComplete="current-password" value={actual} onChange={(e) => setActual(e.target.value)} required /></label>
          <label className="field"><span>Nueva contraseña (mín. 8 caracteres)</span><input className="input" type="password" autoComplete="new-password" minLength={8} value={nueva} onChange={(e) => setNueva(e.target.value)} required /></label>
          <label className="field"><span>Repetir nueva contraseña</span><input className="input" type="password" autoComplete="new-password" value={rep} onChange={(e) => setRep(e.target.value)} required /></label>
          <button className="btn primary">Cambiar contraseña</button>
        </form>
      </div>
    </Shell>
  );
}
