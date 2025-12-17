//
//  ImageLoader.swift
//  BF6StatsTracker
//
//  Handles loading and caching of game images from Battlefield assets
//

import SwiftUI
import Combine

// MARK: - Image Loader

@MainActor
class ImageLoader: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading = false
    @Published var error: Error?
    
    private static var imageCache = NSCache<NSURL, NSImage>()
    private var cancellable: AnyCancellable?
    private let url: URL?
    
    init(url: URL?) {
        self.url = url
    }
    
    func load() {
        guard let url = url else {
            self.image = nil
            return
        }
        
        // Check cache first
        if let cached = Self.imageCache.object(forKey: url as NSURL) {
            self.image = cached
            return
        }
        
        isLoading = true
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { NSImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loadedImage in
                self?.isLoading = false
                self?.image = loadedImage
                
                if let image = loadedImage {
                    Self.imageCache.setObject(image, forKey: url as NSURL)
                }
            }
    }
    
    func cancel() {
        cancellable?.cancel()
    }
    
    static func clearCache() {
        imageCache.removeAllObjects()
    }
}

// MARK: - Async Image Loader View

struct AsyncGameImage: View {
    @StateObject private var loader: ImageLoader
    let placeholder: Image
    let contentMode: ContentMode
    
    init(url: URL?, placeholder: Image = Image(systemName: "photo"), contentMode: ContentMode = .fit) {
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
        self.placeholder = placeholder
        self.contentMode = contentMode
    }
    
    var body: some View {
        content
            .onAppear { loader.load() }
            .onDisappear { loader.cancel() }
    }
    
    @ViewBuilder
    private var content: some View {
        if loader.isLoading {
            ProgressView()
                .scaleEffect(0.5)
        } else if let image = loader.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            placeholder
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Game Asset URLs

struct GameAssetURLs {
    // Base URLs for Battlefield assets
    private static let eaAssetBase = "https://eaassets-a.akamaihd.net/battlelog"
    private static let cdnBase = "https://cdn.gametools.network"
    
    // MARK: - Weapon Images
    
    static func weaponImageURL(name: String, category: String? = nil) -> URL? {
        let cleanName = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
        
        // Try multiple URL patterns
        let urls = [
            "\(cdnBase)/bf6/weapons/\(cleanName).png",
            "\(eaAssetBase)/bf6/weapons/\(cleanName).png",
            "\(cdnBase)/bf6/weapons/large/\(cleanName).png"
        ]
        
        return URL(string: urls.first ?? "")
    }
    
    // MARK: - Vehicle Images
    
    static func vehicleImageURL(name: String, category: String? = nil) -> URL? {
        let cleanName = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
        
        let urls = [
            "\(cdnBase)/bf6/vehicles/\(cleanName).png",
            "\(eaAssetBase)/bf6/vehicles/\(cleanName).png"
        ]
        
        return URL(string: urls.first ?? "")
    }
    
    // MARK: - Gadget Images
    
    static func gadgetImageURL(name: String) -> URL? {
        let cleanName = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
        
        let urls = [
            "\(cdnBase)/bf6/gadgets/\(cleanName).png",
            "\(eaAssetBase)/bf6/gadgets/\(cleanName).png"
        ]
        
        return URL(string: urls.first ?? "")
    }
    
    // MARK: - Class Images
    
    static func classImageURL(className: String) -> URL? {
        let cleanName = className.lowercased()
        
        let urls = [
            "\(cdnBase)/bf6/classes/\(cleanName).png",
            "\(eaAssetBase)/bf6/classes/\(cleanName).png",
            "\(cdnBase)/bf6/classes/icons/\(cleanName).png"
        ]
        
        return URL(string: urls.first ?? "")
    }
    
    // MARK: - Rank Emblems
    
    static func rankImageURL(rank: Int) -> URL? {
        let urls = [
            "\(cdnBase)/bf6/ranks/\(rank).png",
            "\(eaAssetBase)/bf6/ranks/\(rank).png"
        ]
        
        return URL(string: urls.first ?? "")
    }
    
    // MARK: - Player Avatar
    
    static func avatarURL(avatarPath: String?) -> URL? {
        guard let path = avatarPath else { return nil }
        
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        
        return URL(string: "\(eaAssetBase)/bf6/avatars/\(path)")
    }
    
    // MARK: - Map Images
    
    static func mapImageURL(mapName: String) -> URL? {
        let cleanName = mapName
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        
        return URL(string: "\(cdnBase)/bf6/maps/\(cleanName).jpg")
    }
}

// MARK: - Class Icon View

struct ClassIconView: View {
    let className: BF6Class
    let size: CGFloat
    let imageURL: String?

    init(className: BF6Class, size: CGFloat, imageURL: String? = nil) {
        self.className = className
        self.size = size
        self.imageURL = imageURL
    }

    var body: some View {
        if let urlString = imageURL, let url = URL(string: urlString) {
            // Use API-provided image
            AsyncGameImage(
                url: url,
                placeholder: Image(systemName: className.iconName)
            )
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(className.color.opacity(0.2))
            )
            .clipShape(Circle())
        } else {
            // Fallback to icon
            ZStack {
                Circle()
                    .fill(className.color.gradient)

                Image(systemName: className.iconName)
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Stat Icon View

struct StatIconView: View {
    let systemName: String
    let color: Color
    let size: CGFloat
    
    init(systemName: String, color: Color = .blue, size: CGFloat = 24) {
        self.systemName = systemName
        self.color = color
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
            
            Image(systemName: systemName)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Platform Icon View

struct PlatformIconView: View {
    let platform: Platform
    let size: CGFloat
    
    var body: some View {
        Group {
            switch platform {
            case .pc:
                Image(systemName: "desktopcomputer")
            case .playstation:
                Image(systemName: "gamecontroller.fill")
            case .xbox:
                Image(systemName: "gamecontroller.fill")
            case .steam:
                Image(systemName: "cloud.fill")
            }
        }
        .font(.system(size: size))
        .foregroundColor(platformColor)
    }
    
    private var platformColor: Color {
        switch platform {
        case .pc: return .blue
        case .playstation: return .indigo
        case .xbox: return .green
        case .steam: return Color(nsColor: .systemGray)
        }
    }
}
