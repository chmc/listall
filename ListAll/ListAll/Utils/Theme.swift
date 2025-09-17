import SwiftUI

struct Theme {
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color("AccentColor")
        static let secondary = Color.secondary
        static let background = Color(UIColor.systemBackground)
        static let groupedBackground = Color(UIColor.systemGroupedBackground)
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let headline = Font.headline.weight(.medium)
        static let body = Font.body
        static let callout = Font.callout
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let smallColor = Color.black.opacity(0.1)
        static let smallRadius: CGFloat = 2
        static let smallX: CGFloat = 0
        static let smallY: CGFloat = 1
        
        static let mediumColor = Color.black.opacity(0.15)
        static let mediumRadius: CGFloat = 4
        static let mediumX: CGFloat = 0
        static let mediumY: CGFloat = 2
        
        static let largeColor = Color.black.opacity(0.2)
        static let largeRadius: CGFloat = 8
        static let largeX: CGFloat = 0
        static let largeY: CGFloat = 4
    }
    
    // MARK: - Animations
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
    }
}

// MARK: - View Modifiers
extension View {
    
    // Card Style
    func cardStyle() -> some View {
        self
            .background(Theme.Colors.background)
            .cornerRadius(Theme.CornerRadius.md)
            .shadow(color: Theme.Shadow.smallColor, radius: Theme.Shadow.smallRadius, x: Theme.Shadow.smallX, y: Theme.Shadow.smallY)
    }
    
    // Primary Button Style
    func primaryButtonStyle() -> some View {
        self
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.primary)
            .cornerRadius(Theme.CornerRadius.md)
    }
    
    // Secondary Button Style
    func secondaryButtonStyle() -> some View {
        self
            .foregroundColor(Theme.Colors.primary)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.primary.opacity(0.1))
            .cornerRadius(Theme.CornerRadius.md)
    }
    
    // Empty State Style
    func emptyStateStyle() -> some View {
        self
            .foregroundColor(Theme.Colors.secondary)
            .multilineTextAlignment(.center)
            .padding(Theme.Spacing.xl)
    }
}
