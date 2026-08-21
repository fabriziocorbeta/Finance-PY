export default function Loading() {
  return (
    <div className="space-y-4">
      <div className="h-7 w-48 rounded bg-surface2 animate-pulse" />
      <div className="grid grid-cols-4 gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-24 rounded-card bg-surface2 animate-pulse" />
        ))}
      </div>
      <div className="h-64 rounded-card bg-surface2 animate-pulse" />
    </div>
  );
}
