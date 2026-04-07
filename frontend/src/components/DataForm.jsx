import { useState } from "react";
import axios from "axios";

function DataForm() {
  const [form, setForm] = useState({ key: "", value: "" });
  const [response, setResponse] = useState(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleChange = (e) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    try {
      const res = await axios.post("/api/data", form);
      setResponse(res.data);
      setForm({ key: "", value: "" });
    } catch (err) {
      setError(err.response?.data?.message || err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <section className="rounded-xl border border-slate-800 bg-slate-950 p-6 shadow-md">
      <h2 className="mb-4 text-xl font-semibold">Submit Data</h2>
      <form className="space-y-3" onSubmit={handleSubmit}>
        <input
          className="w-full rounded border border-slate-700 bg-slate-900 px-3 py-2"
          name="key"
          placeholder="key"
          value={form.key}
          onChange={handleChange}
          required
        />
        <input
          className="w-full rounded border border-slate-700 bg-slate-900 px-3 py-2"
          name="value"
          placeholder="value"
          value={form.value}
          onChange={handleChange}
          required
        />
        <button
          type="submit"
          disabled={loading}
          className="rounded bg-indigo-600 px-4 py-2 font-medium hover:bg-indigo-500 disabled:opacity-60"
        >
          {loading ? "Submitting..." : "Submit"}
        </button>
      </form>

      {error && <p className="mt-3 text-sm text-red-400">{error}</p>}

      {response && (
        <pre className="mt-4 overflow-auto rounded bg-slate-900 p-3 text-xs text-slate-200">
          {JSON.stringify(response, null, 2)}
        </pre>
      )}
    </section>
  );
}

export default DataForm;
