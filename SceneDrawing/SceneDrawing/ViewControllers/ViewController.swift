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
import GoogleMobileAds

final class ViewController: UIViewController {
    
    @IBOutlet private weak var bannerView: GADBannerView!
    @IBOutlet private weak var sceneView: ARSCNView!
    @IBOutlet private weak var mappingStatusLabel: UILabel!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var fontSizeSlider: UISlider!
    
    private var multipeerSession: MultipeerSession!
    private let device = MTLCreateSystemDefaultDevice()!
    
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
        
        bannerView.adUnitID = "ca-app-pub-7093305833453939/6395761770"
        bannerView.rootViewController = self
        bannerView.load(GADRequest())
        
        sceneView.scene = SCNScene()
        sceneView.session.delegate = self
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = [.showFeaturePoints]
        
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        reloadWorld(session: sceneView.session)
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
        
        let finger = touches.first!.location(in: view)
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
            self.reloadWorld(session: self.sceneView.session)
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
                self.showAlert(isCancel: false, title: "", message: "保存に成功しました")
                self.multipeerSession.sendToAllPeers(data)
            } catch {
                self.showAlert(isCancel: false, title: "エラー", message: "\(error.localizedDescription)")
            }
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
            reloadWorld(session: sceneView.session, worldMap: worldMap)
            self.showAlert(isCancel: false, title: "", message: "読み込みに成功しました")
        } catch {
            self.showAlert(isCancel: false, title: "エラー", message: "\(error.localizedDescription)")
            return
        }
    }
    
    private func receivedData(_ data: Data, from peer: MCPeerID) {
        if let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
            reloadWorld(session: sceneView.session, worldMap: worldMap)
            self.showAlert(isCancel: false, title: "", message: "世界情報を受け取りました")
        }
        if let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: DrawAnchor.self, from: data) {
            sceneView.session.add(anchor: anchor)
        }
    }
    
    private func reloadWorld(session: ARSession, worldMap: ARWorldMap? = nil) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        if let worldMap = worldMap {
            configuration.initialWorldMap = worldMap
        }
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
}

extension ViewController: ARSCNViewDelegate {
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let drawAnchor = anchor as? DrawAnchor, let name = drawAnchor.name, name.hasPrefix("Node") {
                let box = self.drawNode.clone()
                
                let size = CGFloat(drawAnchor.size)
                box.geometry = SCNBox(width: size, height: size, length: size, chamferRadius: 1)
                box.geometry!.firstMaterial?.diffuse.contents = drawAnchor.color
                box.position = SCNVector3(drawAnchor.transform.columns.3.x, drawAnchor.transform.columns.3.y, drawAnchor.transform.columns.3.z)
                self.sceneView.scene.rootNode.addChildNode(box)
            }
            if let planeAnchor = anchor as? ARPlaneAnchor {
                let planeGeometry = ARSCNPlaneGeometry(device: self.device)!
                let color = planeAnchor.alignment == .horizontal ? UIColor.blue : UIColor.green
                planeGeometry.materials.first?.diffuse.contents = color.withAlphaComponent(0.001)
                planeGeometry.update(from: planeAnchor.geometry)
                let planeNode = SCNNode(geometry: planeGeometry)
                planeNode.renderingOrder = -1
                node.addChildNode(planeNode)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                node.childNodes
                    .compactMap { $0.geometry as? ARSCNPlaneGeometry }
                    .first?.update(from: planeAnchor.geometry)
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
                self.mappingStatusLabel.text = "周囲のスキャンしてください\n\(peerName)"
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
