import Foundation

struct ProviderPreset: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
}

let providerPresets: [ProviderPreset] = [
    ProviderPreset(name: "OpenAI", icon: "brain"),
    ProviderPreset(name: "Anthropic", icon: "person.crop.square"),
    ProviderPreset(name: "Google AI", icon: "sparkles"),
    ProviderPreset(name: "AWS", icon: "cloud"),
    ProviderPreset(name: "Azure", icon: "cloud.fill"),
    ProviderPreset(name: "GitHub", icon: "chevron.left.forwardslash.chevron.right"),
    ProviderPreset(name: "Supabase", icon: "server.rack"),
    ProviderPreset(name: "Stripe", icon: "creditcard"),
    ProviderPreset(name: "Twilio", icon: "phone"),
    ProviderPreset(name: "Mapbox", icon: "map"),
    ProviderPreset(name: "Custom", icon: "network")
]
