import { useEffect, useState } from "react";
import axios from "axios";

function StatusCard() {
  const [statusData, setStatusData] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let timer;

    const fetchStatus = async () => {
      try {
        const res = await axios.get("/api/status");
        setStatusData(res.data);
        setError("");
      } catch (err) {
        setError(err.message);
      }
    };

    fetchStatus();
    timer = setInterval(fetchStatus, 5000);

    return () => clearInterval(timer);
  }, []);

  return (
    <section className="rounded-xl border border-slate-800 bg-slate-950 p-6 shadow-md">
      <h2 className="mb-4 text-xl font-semibold">Service Status</h2>
      {error && <p className="text-sm text-red-400">Error: {error}</p>}
      {!statusData && !error && <p className="text-sm text-slate-400">Loading status...</p>}

      {statusData && (
        <div className="space-y-2 text-sm">
          <p>
            Status:{" "}
            <span className="rounded bg-emerald-600 px-2 py-1 font-medium">{statusData.status}</span>
          </p>
          <p>Version: {statusData.version}</p>
          <p>Uptime: {statusData.uptime}s</p>
          <p>Environment: {statusData.environment}</p>
          <p>Deploy Color: {statusData.color}</p>
          <p className="text-slate-400">Timestamp: {statusData.timestamp}</p>
        </div>
      )}
    </section>
  );
}

export default StatusCard;
