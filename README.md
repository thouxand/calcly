# Calcly – calculus på rygraden

En iPhone-app, hvor du øver differentiation og integration i Duolingo-stil, til reglerne sidder på rygraden. Bygget i SwiftUI med Liquid Glass fra iOS 26.

## Kør appen
1. Åbn `Calcly.xcodeproj` i **Xcode 26** (Xcode 16 virker også; så bliver glasset til frostet glas).
2. Vælg projektet **Calcly** → target **Calcly** → **Signing & Capabilities** → vælg dit Apple-ID som **Team**.
   Får du en fejl om bundle-id, så skift `dk.calcly.app` til noget unikt, fx `dk.ditnavn.calcly`.
3. Vælg din iPhone (med kabel) eller en simulator, og tryk **⌘R**.

Kræver iOS 18 eller nyere. På iOS 26 får du ægte Liquid Glass.

## Det kan appen
**Lær** – en sti med 7 enheder og 22 lektioner:
- Differentiation: potensreglen, standardfunktioner, summer
- Produkt- og kvotientreglen
- Kædereglen: indre og ydre funktion, kx indeni, polynomier indeni
- Integration: potenser, standardintegraler, kx indeni
- Substitution og delvis integration
- Mester: alt blandet og Mesterprøven

Hver lektion har 10 opgaver af typerne vælg-svaret, sandt/falsk, find parrene og byg svaret med brikker. Opgaverne bliver lavet på stedet, så de er nye hver gang. Svarer du forkert, kommer opgaven igen sidst i lektionen, og du får reglen forklaret. Hver lektion kan tages op til 5 gange for at få 5 kroner.

**Lynrunde** – 60 sekunder med hurtige spørgsmål ("quick knowledge"). Point for hvert rigtigt svar og bonus for stimer. Rekorden bliver gemt.

**Kort** – 30 regelkort (afledte, stamfunktioner, produkt-, kvotient- og kædereglen, substitution, delvis integration). Kortene kommer igen efter 1, 2, 4, 8 og 16 dage, når du kan dem, så de sidder fast.

**Profil** – streak, XP, præcision, kroner, ugegraf og dagligt mål. Hjerter kan slås fra, og alle lektioner kan låses op.

## Filer
| Fil | Indhold |
|---|---|
| `CalclyApp.swift` | App-start, faner og lagring af fremskridt |
| `Course.swift` | Enheder, lektioner, tips og regelkort |
| `Exercises.swift` | Opgavegeneratorer for hver regel |
| `MathFormat.swift`, `MathMarkup.swift`, `MathText.swift` | Brøker og potenser: formatering og visning |
| `ProgressState.swift` | XP, streak, hjerter, kroner og kort |
| `PathView.swift` | Lektionsstien |
| `LessonView.swift` | Lektionen, opgavetyperne og resultatskærmen |
| `QuickView.swift` | Lynrunden |
| `CardsView.swift` | Regelkortene |
| `ProfileView.swift` | Statistik og indstillinger |
| `Theme.swift` | Liquid Glass, knapper og baggrund |
