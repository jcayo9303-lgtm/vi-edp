"use client";
import { Suspense } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Shell } from "@/components/shell";
import { ResourceTable } from "@/components/resource";
import { MORE_RESOURCES, RESOURCES } from "@/lib/modules";

function DatosInner() {
  const t = useSearchParams().get("t") ?? "parcelas";
  const cfg = RESOURCES[t];
  if (!cfg) return <Shell title="No encontrado"><div className="empty">Módulo no encontrado</div></Shell>;
  return (
    <Shell title={cfg.title} crumbs={["Registros"]}>
      {cfg.description && <p className="muted" style={{ margin: "-10px 0 14px" }}>{cfg.description}</p>}
      <ResourceTable key={t} resource={t} />
      {["personal", "variedades", "productos", "fincas", "lotes", "propietarios", ...MORE_RESOURCES].includes(t) ? (
        <div className="row-wrap small" style={{ marginTop: 14 }}>
          <span className="muted">Otros catálogos:</span>
          {MORE_RESOURCES.map((m) => <Link key={m} className="badge" href={`/datos?t=${m}`}>{RESOURCES[m].title}</Link>)}
        </div>
      ) : null}
    </Shell>
  );
}

export default function DatosPage() {
  return <Suspense><DatosInner /></Suspense>;
}
