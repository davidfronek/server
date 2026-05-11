import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/')({
  component: Home,
})

function Home() {
  return (
    <main className="construction-page">
      <div className="ambient-grid" aria-hidden="true" />
      <div className="orb orb-a" aria-hidden="true" />

      <section className="construction-card">
        <p className="status-tag">Deployment status: compiling coffee</p>
        <h1>Under Construction</h1>
        <p className="lead">
          Nasi developeri jsou momentalne ve stavu{' '}
          <code>git rebase --continue</code>. Mezitim se sklada jemnejsi a cistsi
          verze site bez zbytecneho hluku.
        </p>

        <div className="jokes-grid">
          <article className="joke-box">
            <h2>Aktualni incident</h2>
            <p>
              Build spadl, protoze backend chtel validaci, frontend chtel svobodu
              a database chtela vikend.
            </p>
          </article>
          <article className="joke-box">
            <h2>ETA nasazeni</h2>
            <p>
              Jakmile se testy prestanou hadat, ze bug je vlastne feature.
            </p>
          </article>
          <article className="joke-box">
            <h2>Plan B</h2>
            <p>
              Kdyz to nepujde dnes, prepneme vse do maintenance modu a budeme
              delat, ze to byl zamer.
            </p>
          </article>
        </div>
      </section>

      <aside className="corner-loader" aria-label="Loading progress">
        <div className="corner-loader__rail" aria-hidden="true">
          <span className="corner-loader__dot" />
          <span className="corner-loader__dot" />
          <span className="corner-loader__dot" />
        </div>
        <div className="corner-loader__text">
          <strong>Deploying</strong>
          <span>clean UI mode</span>
        </div>
      </aside>
    </main>
  )
}
