import Foundation

public enum BuiltInAssociationCatalog {
    public static let descriptors: [AssociationDescriptor] = [
        .init(
            association: .urlScheme("http"),
            localizationKey: "association.http",
            category: .web,
            filenameExtensions: [],
            mimeTypes: []
        ),
        .init(
            association: .urlScheme("https"),
            localizationKey: "association.https",
            category: .web,
            filenameExtensions: [],
            mimeTypes: []
        ),
        .init(
            association: .urlScheme("mailto"),
            localizationKey: "association.mailto",
            category: .communication,
            filenameExtensions: [],
            mimeTypes: []
        ),
        .init(
            association: .contentType("public.html"),
            localizationKey: "association.html",
            category: .web,
            filenameExtensions: ["html", "htm"],
            mimeTypes: ["text/html"]
        ),
        .init(
            association: .contentType("com.adobe.pdf"),
            localizationKey: "association.pdf",
            category: .document,
            filenameExtensions: ["pdf"],
            mimeTypes: ["application/pdf"]
        ),
        .init(
            association: .contentType("net.daringfireball.markdown"),
            localizationKey: "association.markdown",
            category: .development,
            filenameExtensions: ["md", "markdown"],
            mimeTypes: ["text/markdown"]
        ),
        .init(
            association: .contentType("public.plain-text"),
            localizationKey: "association.plainText",
            category: .document,
            filenameExtensions: ["txt"],
            mimeTypes: ["text/plain"]
        ),
        .init(
            association: .contentType("public.png"),
            localizationKey: "association.png",
            category: .image,
            filenameExtensions: ["png"],
            mimeTypes: ["image/png"]
        ),
        .init(
            association: .contentType("public.jpeg"),
            localizationKey: "association.jpeg",
            category: .image,
            filenameExtensions: ["jpg", "jpeg"],
            mimeTypes: ["image/jpeg"]
        ),
        .init(
            association: .contentType("public.heic"),
            localizationKey: "association.heic",
            category: .image,
            filenameExtensions: ["heic"],
            mimeTypes: ["image/heic"]
        ),
        .init(
            association: .contentType("com.compuserve.gif"),
            localizationKey: "association.gif",
            category: .image,
            filenameExtensions: ["gif"],
            mimeTypes: ["image/gif"]
        ),
        .init(
            association: .contentType("public.tiff"),
            localizationKey: "association.tiff",
            category: .image,
            filenameExtensions: ["tif", "tiff"],
            mimeTypes: ["image/tiff"]
        ),
        .init(
            association: .contentType("public.audio"),
            localizationKey: "association.audio",
            category: .media,
            filenameExtensions: [],
            mimeTypes: ["audio/*"]
        ),
        .init(
            association: .contentType("public.movie"),
            localizationKey: "association.video",
            category: .media,
            filenameExtensions: [],
            mimeTypes: ["video/*"]
        ),
        .init(
            association: .contentType("public.archive"),
            localizationKey: "association.archive",
            category: .archive,
            filenameExtensions: ["zip", "tar", "gz"],
            mimeTypes: ["application/zip"]
        )
    ]

    public static let smartGroups: [SmartGroupDefinition] = [
        .init(
            id: "browser",
            localizationKey: "smartGroup.browser",
            associations: [
                .urlScheme("http"),
                .urlScheme("https"),
                .contentType("public.html")
            ]
        ),
        .init(
            id: "email",
            localizationKey: "smartGroup.email",
            associations: [.urlScheme("mailto")]
        ),
        .init(
            id: "commonImages",
            localizationKey: "smartGroup.commonImages",
            associations: [
                .contentType("public.png"),
                .contentType("public.jpeg"),
                .contentType("public.heic"),
                .contentType("com.compuserve.gif"),
                .contentType("public.tiff")
            ]
        )
    ]
}
