# Calcly – calculus på rygraden

En iPhone-app, hvor du øver differentiation og integration i Duolingo-stil, til reglerne sidder på rygraden. Bygget i SwiftUI med Liquid Glass fra iOS 26.

## Kør appen
1. Åbn `Calcly.xcodeproj` i **Xcode 26** (Xcode 16 virker også; så bliver glasset til frostet glas).
2. Vælg projektet **Calcly** → target **Calcly** → **Signing & Capabilities** → vælg dit Apple-ID som **Team**.
   Gør det samme for target **CalclyWidgetExtension** (widgetten).
   Får du en fejl om bundle-id, så skift `dk.calcly.app` til noget unikt, fx `dk.ditnavn.calcly`. Widgetten skal så hedde det samme med `.widget` bagefter, fx `dk.ditnavn.calcly.widget`.
3. Vælg din iPhone (med kabel) eller en simulator, og tryk **⌘R**.

Kræver iOS 18 eller nyere. På iOS 26 får du ægte Liquid Glass.

## Det kan appen
**Lær** – en sti med 10 enheder og 26 lektioner:
- Differentiation: potensreglen, standardfunktioner, summer
- Produkt- og kvotientreglen
- Kædereglen: indre og ydre funktion, kx indeni, polynomier indeni
- Integration: potenser, standardintegraler, kx indeni
- Substitution og delvis integration
- Grænseværdier, bestemte integraler og partielle afledte
- Mester: alt blandet og Mesterprøven

Hver lektion har 10 opgaver af typerne vælg-svaret, sandt/falsk, find parrene, byg svaret med brikker, trin for trin og skriv selv svaret med et matematik-tastatur (alle ligeværdige skrivemåder tæller som rigtige). Typerne blandes i hver lektion, ligesom i Duolingo; trin for trin dukker op ved produktreglen, kædereglen og substitution. Ved afledte kan du se grafen for f og f′ i feedbacken. Opgaverne bliver lavet på stedet, så de er nye hver gang. Svarer du forkert, kommer opgaven igen sidst i lektionen, og du får reglen forklaret. Hver lektion kan tages op til 5 gange for at få 5 kroner. Forkerte svar samles under **Øv dine fejl** øverst på stien.

**Lynrunde** – 60 sekunder med hurtige spørgsmål ("quick knowledge"). Point for hvert rigtigt svar og bonus for stimer. Rekorden bliver gemt.

**Kort** – 30 regelkort (afledte, stamfunktioner, produkt-, kvotient- og kædereglen, substitution, delvis integration). Vend kortet og tryk ✓ eller ✗ (eller swipe). Kortene kommer igen efter 1, 2, 4, 8 og 16 dage, når du kan dem, så de sidder fast.

**Cal**, en lille ∫-maskot, hepper på dig. Der er lydeffekter (kan slås fra).

**Widget** – "Dagens regel" på hjemmeskærmen og låseskærmen, en ny hver dag.

**Profil** – streak, XP, præcision, kroner, ugegraf og dagligt mål. 14 bedrifter, streak-frys (én fridag om ugen), daglig påmindelse på et valgfrit tidspunkt, lyde til/fra og lys, mørk eller automatisk udseende. Hjerter kan slås fra, og alle lektioner kan låses op.

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
| `Evaluator.swift` | Tjekker indtastede svar ved at regne dem ud |
| `LessonExtras.swift` | Matematik-tastatur, trin for trin og grafer |
| `Extras.swift` | Lyde, påmindelser og maskotten Cal |
| `Sounds/` | Lydeffekterne |
| `CalclyWidget/` | Widgetten "Dagens regel" |
| `Theme.swift` | Liquid Glass, knapper og baggrund |
