// On a Mac: swift tools/export_villager_scn.swift Assets/Generated/PixelQuest/3d
import Foundation
import SceneKit
import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Assets/Generated/PixelQuest/3d", isDirectory: true)
for name in ["villager-house", "villager-house-oak", "villager-house-spruce", "villager-house-birch", "villager-house-sand"] {
    let scene = try SCNScene(url: directory.appendingPathComponent(name + ".usdz"), options: nil)
    scene.rootNode.enumerateChildNodes { node, _ in
        node.removeAllAnimations()
        for material in node.geometry?.materials ?? [] {
            for property in [material.diffuse, material.emission, material.normal, material.roughness, material.metalness, material.transparent] {
                property.minificationFilter = .nearest
                property.magnificationFilter = .nearest
                property.mipFilter = .none
                property.maxAnisotropy = 1
                // Resolve external image references before archiving the scene.
                if let url = property.contents as? URL, let image = NSImage(contentsOf: url) {
                    property.contents = image
                }
            }
        }
    }
    let target = directory.appendingPathComponent(name + ".scn")
    let data = try NSKeyedArchiver.archivedData(withRootObject: scene, requiringSecureCoding: false)
    try data.write(to: target, options: .atomic)
    let check = try SCNScene(url: target, options: nil)
    var triangles = 0
    check.rootNode.enumerateChildNodes { node, _ in
        for element in node.geometry?.elements ?? [] where element.primitiveType == .triangles { triangles += element.primitiveCount }
        for material in node.geometry?.materials ?? [] {
            precondition(material.diffuse.magnificationFilter == .nearest)
            precondition(material.diffuse.minificationFilter == .nearest)
        }
        precondition(node.animationKeys.isEmpty)
    }
    precondition(triangles > 0 && triangles < 5000)
    print("Validated \(target.lastPathComponent): \(triangles) triangles")
}
