import SwiftUI

struct Floor: View {
    private func rect(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .circular)
            .fill(color)
            .frame(width: 50, height: 50)
    }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .circular)
                .fill(Color(red: 0.50, green: 0.47, blue: 0.45))
                .frame(width: 100, height: 100)
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                    rect(Color(red: 0.84, green: 0.81, blue: 0.71))
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                    rect(Color(red: 0.84, green: 0.81, blue: 0.71))
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                }
                GridRow {
                    rect(Color(red: 0.84, green: 0.81, blue: 0.71))
                    rect(Color(red: 0.50, green: 0.47, blue: 0.45))
                    rect(Color(red: 0.71, green: 0.67, blue: 0.63))
                    rect(Color(red: 0.71, green: 0.67, blue: 0.63))
                    rect(Color(red: 0.50, green: 0.47, blue: 0.45))
                    rect(Color(red: 0.84, green: 0.81, blue: 0.71))
                }
                GridRow {
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                    rect(Color(red: 0.71, green: 0.67, blue: 0.63))
                    rect(.clear)
                    rect(.clear)
                    rect(Color(red: 0.71, green: 0.67, blue: 0.63))
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                }
                GridRow {
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                    rect(Color(red: 0.71, green: 0.67, blue: 0.63))
                    rect(.clear)
                    rect(.clear)
                    rect(Color(red: 0.71, green: 0.67, blue: 0.63))
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                }
                GridRow {
                    rect(Color(red: 0.84, green: 0.81, blue: 0.71))
                    rect(Color(red: 0.50, green: 0.47, blue: 0.45))
                    rect(Color(red: 0.71, green: 0.67, blue: 0.63))
                    rect(Color(red: 0.71, green: 0.67, blue: 0.63))
                    rect(Color(red: 0.50, green: 0.47, blue: 0.45))
                    rect(Color(red: 0.84, green: 0.81, blue: 0.71))
                }
                GridRow {
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                    rect(Color(red: 0.84, green: 0.81, blue: 0.71))
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                    rect(Color(red: 0.84, green: 0.81, blue: 0.71))
                    rect(Color(red: 0.88, green: 0.85, blue: 0.81))
                }
            }
        }
        .rotationEffect(.degrees(45))
        .clipped()
        .background(Color(red: 0.96, green: 0.93, blue: 0.89))
    }
}

#Preview {
    Floor()
}
