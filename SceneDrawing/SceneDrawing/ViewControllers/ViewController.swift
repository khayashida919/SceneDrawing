//
//  ViewController.swift
//  SceneDrawing
//
//  Created by khayashida on 2019/04/11.
//  Copyright © 2019 khayashida. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import MultipeerConnectivity

final class ViewController: UIViewController {
    
    @IBOutlet private weak var sceneView: ARSCNView!
    @IBOutlet private weak var mappingStatusLabel: UILabel!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var fontSizeSlider: UISlider!
    
    var multipeerSession: MultipeerSession!
    
    private var drawNode = SCNNode()
    private var nodeColor: UIColor = .white
    private let worldMapPath: URL? = {
        guard let document = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return document.appendingPathComponent("worldMap").appendingPathExtension("dat")
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.scene = SCNScene()
        sceneView.session.delegate = self
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = [.showFeaturePoints]
        
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let infrontOfCamera = SCNVector3(x: 0, y: 0, z: -0.2)
        guard let cameraNode = sceneView.pointOfView else { return }
        let pointInWorld = cameraNode.convertPosition(infrontOfCamera, to: nil)
        var screenPosition = sceneView.projectPoint(pointInWorld)
        
        let finger = touches.first!.location(in: nil)
        screenPosition.x = Float(finger.x)
        screenPosition.y = Float(finger.y)
        let finalPosition = sceneView.unprojectPoint(screenPosition)
        
        let boxNode = drawNode.clone()
        boxNode.position = finalPosition
        let nodeAnchor = DrawAnchor(name: "Node", transform: boxNode.simdTransform, color: nodeColor, size: fontSizeSlider.value)
        sceneView.session.add(anchor: nodeAnchor)
        
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: nodeAnchor, requiringSecureCoding: true) else {
            fatalError("can't encode anchor")
        }
        self.multipeerSession.sendToAllPeers(data)
    }
    
    @IBAction func removeAction(_ sender: UIButton) {
        showAlert(isCancel: true, title: "確認", message: "削除しますか？") {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
    }
    
    @IBAction func colorAction(_ sender: UIButton) {
        nodeColor = sender.tintColor
    }
    
    @IBAction func saveMapAction(_ sender: UIButton) {
        sceneView.session.getCurrentWorldMap { (worldMap, error) in
            guard
                error == nil,
                let worldMap = worldMap,
                let worldMapPath = self.worldMapPath else {
                    return
            }
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
                try data.write(to: worldMapPath)
                self.multipeerSession.sendToAllPeers(data)
            } catch {
                self.showAlert(isCancel: false, title: "エラー", message: "\(error.localizedDescription)")
                return
            }
            self.showAlert(isCancel: false, title: "", message: "保存に成功しました")
        }
    }
    
    @IBAction func loadMapAction(_ sender: UIButton) {
        guard let worldMapPath = worldMapPath else {
            return
        }
        do {
            let data = try Data(contentsOf: worldMapPath)
            guard let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                return
            }
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = .horizontal
            configuration.initialWorldMap = worldMap
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            self.showAlert(isCancel: false, title: "", message: "読み込みに成功しました")
        } catch {
            self.showAlert(isCancel: false, title: "エラー", message: "\(error.localizedDescription)")
            return
        }
    }
    
    private func receivedData(_ data: Data, from peer: MCPeerID) {
        if let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.initialWorldMap = worldMap
            sceneView.session.run(configuration/*, options: [.resetTracking, .removeExistingAnchors]*/)
            self.showAlert(isCancel: false, title: "", message: "世界情報を受け取りました")
        }
        if let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: DrawAnchor.self, from: data) {
            sceneView.session.add(anchor: anchor)
        }
    }
}

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let drawAnchor = anchor as? DrawAnchor, let name = drawAnchor.name, name.hasPrefix("Node") {
                let box = self.drawNode.clone()
                
                let size = CGFloat(drawAnchor.size)
                box.geometry = SCNBox(width: size, height: size, length: size, chamferRadius: 1)
                box.position = SCNVector3(drawAnchor.transform.columns.3.x, drawAnchor.transform.columns.3.y, drawAnchor.transform.columns.3.z)
                box.geometry!.firstMaterial?.diffuse.contents = drawAnchor.color
                self.sceneView.scene.rootNode.addChildNode(box)
            }
        }
    }
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {
            let peerName = "\(self.multipeerSession.connectedPeers.map { $0.displayName }.joined(separator: "\n"))"
            switch frame.worldMappingStatus {
            case .notAvailable, .limited:
                self.saveButton.isEnabled = false
                self.saveButton.alpha = 0.1
                self.mappingStatusLabel.text = "スキャンし続けてください\n\(peerName)"
            case .extending, .mapped:
                self.saveButton.isEnabled = true
                self.saveButton.alpha = 1
                self.mappingStatusLabel.text = "マッピング状態良好\n\(peerName)"
            @unknown default:
                fatalError()
            }
        }
        
    }
}

