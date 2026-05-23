import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                    .foregroundColor(star <= (rating ?? 0) ? .yellow : .gray)
                    .onTapGesture {
                        rating = (rating == star) ? nil : star
                    }
            }
        }
    }
}
