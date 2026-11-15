// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenMP3Probe",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [.library(name: "ProbeCore", targets: ["ProbeCore"]),
               .executable(name: "drive-probe", targets: ["DriveProbe"])],
    targets: [.target(name: "ProbeCore"),
              .executableTarget(name: "DriveProbe", dependencies: ["ProbeCore"]),
              .testTarget(name: "ProbeCoreTests", dependencies: ["ProbeCore"])]
)
