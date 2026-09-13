---
name: swift-development
description: "Swift development with SPM packages and Xcode projects."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [swift, xcode, spm, package-manager, macos, ios, cli]
    related_skills: [spike, test-driven-development]
---

# Swift Development

Use this skill for Swift development workflows — SPM packages, Xcode projects, CLI tools, and macOS/iOS prototyping. Load when building Swift applications, libraries, or command-line tools on macOS.

## Swift Package Manager (SPM) Workflow

### Project Initialization
```bash
# Executable package
swift package init --type executable --name DemoApp

# Library package  
swift package init --type library --name MyLibrary

# Empty package
swift package init
```

### Package.swift Configuration
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DemoApp",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "DemoApp",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "DemoAppTests",
            dependencies: ["DemoApp"]
        ),
    ]
)
```

### Building and Running
```bash
# Debug build and run
swift run

# Release build
swift build --configuration release

# Run release binary
./.build/release/DemoApp

# Test specific test case
swift test --filter TestName

# Run all tests
swift test
```

### Interactive CLI Demos
For input/output interaction in CLI tools:
```swift
print("🚀 Demo gestartet!")
print("Gib eine Zahl ein: ", terminator: "")
if let input = readLine(), let number = Int(input) {
    print("Ergebnis: \(number * number)")
} else {
    print("Ungültige Eingabe!")
}
```

**Automated input testing:**
```bash
echo "5" | swift run  # Pipes input to the executable
```

## Xcode Project Creation

When Xcode MCP tools are unavailable, use SPM as an alternative for simple prototypes and CLI tools.

### Checking Xcode Availability
```bash
# Check Xcode installation
xcode-select -p

# List Xcode templates
find /Applications/Xcode.app/Contents/Developer/Library/Xcode/Templates/ -name "*.xctemplate" | head -10
```

### SPM vs Xcode Projects

**Use SPM when:**
- Building CLI tools or libraries
- No complex UI required
- Multi-platform support needed
- Preferring command-line workflow
- Xcode project templates unavailable

**Use Xcode when:**
- Building iOS/macOS apps with UI
- Interface Builder needed
- Complex project configuration required
- Team uses Xcode workflow

## Testing Patterns

### Basic Test Structure
```swift
import Testing
@testable import DemoApp

@Test func testCalculation() {
    // Arrange
    let input = 7
    let expected = 49
    
    // Act
    let result = input * input
    
    // Assert
    #expect(result == expected, "Square of \(input) should be \(expected), got \(result)")
}

@Test func testAppName() {
    let appName = "DemoApp"
    #expect(appName == "DemoApp")
}
```

### Test Execution
- Tests run with `swift test`
- Filter specific tests with `--filter TestName`
- Build completes before test execution
- Test output shows pass/fail status with timing

## Common Pitfalls

- **Missing Xcode**: Ensure Xcode is installed and `xcode-select -p` returns correct path
- **SPM version**: Check `swift-tools-version` compatibility in Package.swift
- **Platform constraints**: Specify minimum OS versions in Package.swift platforms array
- **Dependency resolution**: Run `swift package resolve` if dependencies fail to load
- **Test discovery**: Ensure test files are in `Tests/<Target>Tests/` directory

## Multi-Platform Support

SPM supports building for multiple Apple platforms:
- macOS (.macOS(.v14))
- iOS (.iOS(.v17)) 
- watchOS (.watchOS(.v10))
- tvOS (.tvOS(.v17))

Platform-specific code can use `#if os(macOS)` conditional compilation.

## When to Choose SPM Over Xcode

SPM is preferred for:
- Command-line tools and utilities
- Server-side Swift applications
- Cross-platform libraries
- Automated build pipelines
- Projects requiring minimal IDE dependency

Xcode is preferred for:
- iOS/macOS apps with UI
- Projects using Interface Builder
- Teams standardized on Xcode
- Complex project configurations
- Debugging with Xcode instruments
