import StatusCard from "./components/StatusCard";
import DataForm from "./components/DataForm";

function App() {
  return (
    <main className="min-h-screen bg-slate-900 px-4 py-10 text-slate-100">
      <div className="mx-auto max-w-5xl">
        <header className="mb-8">
          <h1 className="text-3xl font-bold">QTEC DevOps Dashboard</h1>
          <p className="mt-2 text-slate-400">
            MERN stack with blue-green deployment, observability, and CI/CD.
          </p>
        </header>

        <div className="grid gap-6 md:grid-cols-2">
          <StatusCard />
          <DataForm />
        </div>
      </div>
    </main>
  );
}

export default App;
