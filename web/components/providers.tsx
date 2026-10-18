"use client";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { usePathname, useRouter } from "next/navigation";
import { AlertTriangle, CheckCircle2, X } from "lucide-react";
import { api, getToken, setToken, type Option, type User } from "@/lib/api";

// ------------------------------------------------------------------ Toasts
type Toast = { id: number; text: string; kind: "ok" | "warn" };
const ToastCtx = createContext<(text: string, kind?: "ok" | "warn") => void>(() => {});
export const useToast = () => useContext(ToastCtx);

// ------------------------------------------------------------------ Confirm
type ConfirmOpts = { title: string; text?: string; ok?: string; danger?: boolean };
const ConfirmCtx = createContext<(o: ConfirmOpts) => Promise<boolean>>(async () => false);
export const useConfirm = () => useContext(ConfirmCtx);

// ------------------------------------------------------------------ Sesión y campaña
interface AppState {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  campanas: (Option & { estado?: string })[];
  campanaId: number | null;
  setCampanaId: (id: number) => void;
  fincas: Option[];
  fincaId: number | null;
  setFincaId: (id: number | null) => void;
  canWrite: boolean;
}
const AppCtx = createContext<AppState>(null as unknown as AppState);
export const useApp = () => useContext(AppCtx);

function readLS(k: string): number | null {
  try {
    const v = localStorage.getItem(k);
    return v ? Number(v) : null;
  } catch {
    return null;
  }
}
function writeLS(k: string, v: number | null) {
  try {
    if (v) localStorage.setItem(k, String(v));
    else localStorage.removeItem(k);
  } catch {}
}

export function Providers({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [campanas, setCampanas] = useState<AppState["campanas"]>([]);
  const [campanaId, setCampanaIdState] = useState<number | null>(null);
  const [fincas, setFincas] = useState<Option[]>([]);
  const [fincaId, setFincaIdState] = useState<number | null>(null);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [confirm, setConfirm] = useState<(ConfirmOpts & { resolve: (b: boolean) => void }) | null>(null);
  const router = useRouter();
  const pathname = usePathname();
  const seq = useRef(0);

  const toast = useCallback((text: string, kind: "ok" | "warn" = "ok") => {
    const id = ++seq.current;
    setToasts((t) => [...t, { id, text, kind }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), kind === "warn" ? 7000 : 3500);
  }, []);

  const askConfirm = useCallback((o: ConfirmOpts) => new Promise<boolean>((resolve) => setConfirm({ ...o, resolve })), []);

  const loadContext = useCallback(async () => {
    const [cs, fs] = await Promise.all([
      api.get<{ rows: { id: number; nombre: string; estado: string }[] }>("/r/campanas", { limit: 50 }),
      api.get<Option[]>("/r/fincas/options"),
    ]);
    const list = cs.rows.map((c) => ({ value: c.id, label: c.nombre, estado: c.estado }));
    setCampanas(list);
    setFincas(fs);
    const saved = readLS("vc_campana");
    const open = list.find((c) => c.estado === "abierta") ?? list[0];
    setCampanaIdState(list.some((c) => c.value === saved) ? saved : open?.value ?? null);
    const sf = readLS("vc_finca");
    setFincaIdState(fs.some((f) => f.value === sf) ? sf : null);
  }, []);

  useEffect(() => {
    if (!getToken()) {
      setLoading(false);
      return;
    }
    api.get<{ user: User }>("/auth/me")
      .then(async (r) => {
        setUser(r.user);
        await loadContext();
      })
      .catch(() => setToken(null))
      .finally(() => setLoading(false));
  }, [loadContext]);

  useEffect(() => {
    if (!loading && !user && pathname !== "/login") router.replace("/login");
  }, [loading, user, pathname, router]);

  const value = useMemo<AppState>(() => ({
    user, loading, campanas, campanaId, fincas, fincaId,
    canWrite: !!user && user.rol !== "consulta",
    login: async (email, password) => {
      const r = await api.post<{ token: string; user: User }>("/auth/login", { email, password });
      setToken(r.token);
      setUser(r.user);
      await loadContext();
    },
    logout: async () => {
      await api.post("/auth/logout").catch(() => {});
      setToken(null);
      setUser(null);
      router.replace("/login");
    },
    setCampanaId: (id) => { setCampanaIdState(id); writeLS("vc_campana", id); },
    setFincaId: (id) => { setFincaIdState(id); writeLS("vc_finca", id); },
  }), [user, loading, campanas, campanaId, fincas, fincaId, loadContext, router]);

  return (
    <AppCtx.Provider value={value}>
      <ToastCtx.Provider value={toast}>
        <ConfirmCtx.Provider value={askConfirm}>
          {children}
          <div className="toasts" role="status" aria-live="polite">
            {toasts.map((t) => (
              <div key={t.id} className={`toast ${t.kind === "warn" ? "warn" : ""}`}>
                {t.kind === "warn" ? <AlertTriangle size={15} /> : <CheckCircle2 size={15} />}
                <span className="grow">{t.text}</span>
                <button className="btn ghost sm icon" style={{ color: "inherit", height: 18, width: 18 }} onClick={() => setToasts((x) => x.filter((y) => y.id !== t.id))} aria-label="Cerrar">
                  <X size={12} />
                </button>
              </div>
            ))}
          </div>
          {confirm && (
            <>
              <div className="overlay" style={{ zIndex: 1100 }} onClick={() => { confirm.resolve(false); setConfirm(null); }} />
              <div className="modal" role="dialog" aria-modal="true">
                <div className="modal-body">
                  <h2>{confirm.title}</h2>
                  {confirm.text && <p className="muted">{confirm.text}</p>}
                </div>
                <div className="modal-foot">
                  <button className="btn" onClick={() => { confirm.resolve(false); setConfirm(null); }}>Cancelar</button>
                  <button autoFocus className="btn primary" onClick={() => { confirm.resolve(true); setConfirm(null); }}>{confirm.ok ?? "Confirmar"}</button>
                </div>
              </div>
            </>
          )}
        </ConfirmCtx.Provider>
      </ToastCtx.Provider>
    </AppCtx.Provider>
  );
}
