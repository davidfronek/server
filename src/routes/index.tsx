import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/')({
  component: Home,
})

function Home() {
  return (
    <main className="construction-page">
      <div className="ambient-grid" aria-hidden="true" />
      <div className="orb orb-a" aria-hidden="true" />
      <div className="orb orb-b" aria-hidden="true" />

      <section className="construction-card">
        <p className="status-tag">Deployment status: compiling coffee</p>
        <h1>Under Construction</h1>
        <p className="lead">
          Nasi developeri jsou momentalne ve stavu{' '}
          <code>git rebase --continue</code> a systemovy architekt bojuje s jednim
          tvrdohlavym semicolonem.
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

        <div className="loader-panel" aria-label="Loading progress">
          <div className="loader-rail" aria-hidden="true">
            <span className="loader-dot loader-dot-a" />
            <span className="loader-dot loader-dot-b" />
            <span className="loader-dot loader-dot-c" />
            <span className="loader-scan" />
          </div>
          <div className="loader-copy">
            <strong>Loading production-grade vibes...</strong>
            <span>Builduje se UI, zatimco server ocekava, ze nekdo zaplati kafe.</span>
          </div>
        </div>

        <div className="console-strip" role="status" aria-live="polite">
          <span>$ npm run fix-everything</span>
          <span>...</span>
          <span>still loading</span>
        </div>
      </section>
    </main>
  )
}
