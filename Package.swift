// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RealmS", // Tên gói của bạn, tương ứng với target chính trong Podfile
    platforms: [
        .iOS(.v8) // Đặt phiên bản iOS tối thiểu từ Podfile của bạn
    ],
    products: [
        // Khai báo sản phẩm chính của bạn
        .library(
            name: "RealmS", // Tên thư viện khi được tích hợp
            targets: ["RealmS"]), // Liên kết đến target RealmS
    ],
    dependencies: [
        // Khai báo các dependency bên ngoài mà RealmS sử dụng
        // RealmSwift tương đương với 'RealmSwift', '~> 3.0'
        .package(url: "https://github.com/realm/realm-swift.git", .upToNextMajor(from: "3.0.0")),
        // ObjectMapper tương đương với 'ObjectMapper', '~> 3.0'
        .package(url: "https://github.com/tristanhimmelman/ObjectMapper.git", .upToNextMajor(from: "3.0.0"))
    ],
    targets: [
        // Target chính cho thư viện RealmS của bạn
        .target(
            name: "RealmS",
            dependencies: [
                .product(name: "RealmSwift", package: "realm-swift"), // Tham chiếu RealmSwift
                .product(name: "ObjectMapper", package: "ObjectMapper") // Tham chiếu ObjectMapper
            ],
            // RẤT QUAN TRỌNG: Điều chỉnh đường dẫn này
            // Giả sử mã nguồn chính của framework RealmS nằm trong thư mục 'Sources/RealmS'
            // hoặc một thư mục khác trong dự án của bạn (ví dụ: 'RealmS/Classes').
            // Bạn cần chắc chắn rằng đường dẫn này trỏ đúng đến nơi chứa các file mã nguồn .swift của RealmS.
            path: "Sources/"
        ),
        // Target cho các bài kiểm thử, tương tự như 'Tests' trong Podfile
        .testTarget(
            name: "RealmSTests", // Đổi tên thành RealmSTests cho rõ ràng
            dependencies: [
                "RealmS", // Phụ thuộc vào target RealmS chính
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "ObjectMapper", package: "ObjectMapper")
            ],
            // Đảm bảo đường dẫn này trỏ đến mã nguồn của các bài kiểm thử
            path: "Tests/" // Ví dụ: đặt các bài kiểm thử trong 'Tests/RealmSTests'
        )
        // SwiftLint là một công cụ phân tích mã, không phải dependency runtime.
        // Bạn sẽ không thêm nó vào dependencies của gói SPM theo cách này.
        // Thay vào đó, bạn có thể thiết lập nó như một Run Script Phase trong dự án của mình
        // hoặc chạy nó như một bước tiền build nếu cần.
    ]
)
