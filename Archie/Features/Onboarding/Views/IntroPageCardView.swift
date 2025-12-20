//
//  IntroPageCardView.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import SwiftUI

struct IntroPageCardView<Footer: View>: View {
    let page: IntroPage
    private let footerBuilder: () -> Footer

    init(page: IntroPage, @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }) {
        self.page = page
        self.footerBuilder = footer
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Image(page.illustrationName)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 350)
                .accessibilityHidden(true)
            
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text(page.title)
                    .font(.title.bold())
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
            
            footerBuilder()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.white)
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 12)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

#if DEBUG
struct IntroPageCardView_Previews: PreviewProvider {
    static var previews: some View {
        IntroPageCardView(page: IntroPage.mockPages[0])
            .padding()
            .background(Color(uiColor: .systemGray6))
    }
}
#endif
