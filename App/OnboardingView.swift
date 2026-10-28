import SwiftUI
import EzMapsCore

/// GM-043: Onboarding im Glas-Look (GM-031/032): Willkommen, Standort (Nutzen vor der iOS-Frage), Stil wählen.
/// GM-045: Zuhause/Arbeit und „Ich habe schon EzMaps“ raus (Nutzer), Neon City vorausgewählt (der Look, mit dem die App wirbt),
/// Hintergrund deckend statt halb durchsichtig über der Startkarte. Kauf-Stile nur „kostenlos testen“ (10 Minuten, GM-041).
struct OnboardingView: View {
    let model: AppModel
    @State private var step = 0
    @State private var pick: MapStyle = .neonCity

    var body: some View {
        ZStack {
            if step == 0 {
                // Karte (im Hintergrund Neon City) oben sichtbar, unten dunkel für den Text
                LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.75), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            } else {
                SwiftUI.Color.black.opacity(0.92).ignoresSafeArea()
            }
            VStack(alignment: .leading, spacing: 0) {
                if step > 0 { StepBar(step: step) }
                switch step {
                case 0: welcome
                case 1: locationStep
                default: styleStep
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            Image("AppIconPreview").resizable().frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.6), radius: 15, y: 10)
            Text("EzMaps").font(.system(size: 52, weight: .black)).tracking(-2)
            Text(L("Deine Stadt als Spielwelt. Echte Navigation für ganz Europa, auch in CarPlay."))
                .font(.system(size: 17)).foregroundStyle(.white.opacity(0.85))
            Button(L("Los geht's")) { step = 1 }.buttonStyle(PrimaryGlassButtonStyle()).padding(.top, 12)
        }
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Kicker(text: String(format: L("Schritt %d von %d"), 1, 2)).padding(.top, 14)
            Text(L("Wo bist du gerade?")).font(.system(size: 30, weight: .heavy))
            Text(L("Damit EzMaps dich navigiert und deine Stadt aufdeckt.")).foregroundStyle(.white.opacity(0.8))
            Spacer()
            Image(systemName: "mappin.circle").font(.system(size: 110, weight: .thin)).foregroundStyle(GlassTokens.accent).frame(maxWidth: .infinity)
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                InfoLine(icon: "location.north", title: L("Karte zeigt dich"), sub: L("Nur während die App offen ist"))
                InfoLine(icon: "speaker.wave.2", title: L("Ansagen laufen weiter"), sub: L("Auch bei gesperrtem iPhone, nur während einer Fahrt"))
            }
            .padding(14).glass(GlassTokens.card)
            Button(L("Standort erlauben")) { model.location.requestPermission(); step = 2 }.buttonStyle(PrimaryGlassButtonStyle())
            Button(L("Später")) { step = 2 }.buttonStyle(GlassButtonStyle())
        }
    }

    private var styleStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Kicker(text: String(format: L("Schritt %d von %d"), 2, 2)).padding(.top, 14)
            Text(L("Wie soll deine Welt aussehen?")).font(.system(size: 30, weight: .heavy)).fixedSize(horizontal: false, vertical: true)
            Text(L("Du kannst jederzeit wechseln.")).foregroundStyle(.white.opacity(0.8))
            ScrollView {
                VStack(spacing: 10) {
                    styleCard(.classic).frame(height: 112)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach([MapStyle.neonCity, .wildWest, .pixelQuest, .toyTown], id: \.self) { s in styleCard(s).frame(height: 128) }
                    }
                }
            }
            Button(pick == .classic ? L("Weiter mit Klassik") : String(format: L("%@ 10 Minuten testen"), L(pick.titleKey))) {
                model.selectStyle(pick)
                finish()
            }
            .buttonStyle(PrimaryGlassButtonStyle())
        }
    }

    private func styleCard(_ s: MapStyle) -> some View {
        Button { pick = s } label: {
            ZStack(alignment: .bottomLeading) {
                StyleSwatch(style: s)
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    StyleName(style: s, size: 15)
                    Text(s.isFree || model.isUnlocked(s) ? L("Inklusive") : L("Kostenlos testen")).font(.system(size: 10.5, weight: .semibold)).opacity(0.85)
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Text(s.isFree ? "GRATIS" : "PLUS").font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(s.isFree ? GlassTokens.ok : GlassTokens.gold, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(.black).padding(6)
            }
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(pick == s ? GlassTokens.accent : .clear, lineWidth: 3) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(pick == s ? .isSelected : [])
    }

    private func finish() {
        model.completeOnboarding()
        // GM-045: keine Standort-Frage mehr am Ende – wer „Später“ wählt, wird erst beim Standort-Knopf gefragt
    }
}

struct StepBar: View {
    let step: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...2, id: \.self) { i in
                Capsule().fill(i <= step ? GlassTokens.accent : SwiftUI.Color.white.opacity(0.2)).frame(height: 4)
            }
        }
        .padding(.top, 8)
        .accessibilityHidden(true)
    }
}

struct InfoLine: View {
    let icon: String
    let title: String
    let sub: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 36, height: 36).neutralGlass(12)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(sub).font(.system(size: 12.5)).foregroundStyle(GlassTokens.secondary)
            }
        }
    }
}

/// Schritt 3: Zuhause und Arbeit (für Schnellziele, Widgets, Siri), überspringbar
struct HomeWorkStep: View {
    let model: AppModel
    let done: () -> Void
    @State private var editing: Int? // 0 = Zuhause, 1 = Arbeit
    @State private var query = ""
    @State private var results: [PhotonClient.Place] = []
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Kicker(text: String(format: L("Schritt %d von %d"), 3, 3)).padding(.top, 14)
            Text(L("Wohin fährst du oft?")).font(.system(size: 30, weight: .heavy))
            Text(L("Dann reicht später ein Tipp oder „Hey Siri, nach Hause“.")).foregroundStyle(.white.opacity(0.8))
            if let e = editing {
                TextField(e == 0 ? L("Adresse Zuhause") : L("Adresse Arbeit"), text: $query)
                    .padding(.horizontal, 14).frame(height: 50).neutralGlass(14, selected: true)
                    .autocorrectionDisabled()
                    .onChange(of: query) {
                        task?.cancel()
                        let q = query
                        task = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard !Task.isCancelled else { return }
                            let found = await model.searchPlaces(q)
                            guard !Task.isCancelled else { return }
                            results = found
                        }
                    }
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(results, id: \.self) { p in
                            Button {
                                model.updateJournal { j in if e == 0 { j.home = p } else { j.work = p } }
                                editing = nil; query = ""; results = []
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                                    Text(p.subtitle).font(.system(size: 12.5)).foregroundStyle(GlassTokens.secondary).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10).neutralGlass(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                field(icon: "house", text: model.journal.home?.name ?? L("Zuhause hinzufügen"), set: model.journal.home != nil) { editing = 0 }
                field(icon: "briefcase", text: model.journal.work?.name ?? L("Arbeit hinzufügen"), set: model.journal.work != nil) { editing = 1 }
                Toggle(isOn: Binding(get: { model.settings.voice }, set: { v in model.updateSettings { $0.voice = v } })) {
                    InfoLine(icon: "speaker.wave.2", title: L("Sprachansagen"), sub: L("Musik wird dabei nur leiser"))
                }
                .padding(14).glass(GlassTokens.card)
                Spacer()
            }
            Button(L("Fertig, los!")) { done() }.buttonStyle(PrimaryGlassButtonStyle())
            Button(L("Überspringen")) { done() }.buttonStyle(GlassButtonStyle())
        }
    }

    private func field(icon: String, text: String, set: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                Text(text).lineLimit(1).opacity(set ? 1 : 0.6)
                Spacer()
            }
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 14).frame(height: 52)
            .neutralGlass(14)
        }
        .buttonStyle(.plain)
    }
}
