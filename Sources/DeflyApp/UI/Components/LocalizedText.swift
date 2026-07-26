import Foundation

enum LocalizedText {
    static func string(
        _ key: String,
        locale: Locale,
        bundle: Bundle = .main
    ) -> String {
        guard
            let path = bundle.path(
                forResource: locale.identifier,
                ofType: "lproj"
            ),
            let localizedBundle = Bundle(path: path)
        else {
            return bundle.localizedString(
                forKey: key,
                value: key,
                table: nil
            )
        }

        return localizedBundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }
}
