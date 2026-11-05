// Página única de la demo. Es un "Server Component": se genera en el servidor.
export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 p-8">
      <h1 className="text-4xl font-bold">¡Servidor en la nube funcionando! ☁️</h1>
      <p className="text-lg text-gray-600">
        Esta app se desplegó sola: GitHub → script de arranque → Lightsail → dominio.
      </p>
    </main>
  );
}
