import SpriteKit
import UIKit

/// Procedural, card-specific cartoon construction. The index drives a stable palette,
/// silhouette family, headgear and weapon profile; team color is reserved for a readable
/// base/trim accent so red and blue versions remain immediately identifiable.
enum CardSpriteFactory {
    static func make(card: CardDefinition, team: Team, size: CGSize) -> SKNode {
        let root = SKNode()
        let index = CardCatalog.all.firstIndex(where: { $0.id == card.id }) ?? 0
        let hue = CGFloat((Double(index) * 0.61803398875).truncatingRemainder(dividingBy: 1))
        let coat = UIColor(hue: hue, saturation: 0.72, brightness: 0.92, alpha: 1)
        let trim = UIColor(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.84, brightness: 0.62, alpha: 1)
        let outline = UIColor(red: 0.055, green: 0.065, blue: 0.10, alpha: 1)
        let skin = UIColor(red: 0.96, green: 0.72, blue: 0.52, alpha: 1)
        let teamColor = team == .blue
            ? UIColor(red: 0.10, green: 0.55, blue: 1.0, alpha: 1)
            : UIColor(red: 1.0, green: 0.20, blue: 0.25, alpha: 1)
        let w = size.width, h = size.height
        let analog = card.analog.lowercased()
        let flying = card.behavior.contains(.flying)
        let skeleton = analog.contains("skeleton") || analog.contains("bone")
        let dragon = analog.contains("dragon") || analog.contains("lava hound")
        let hog = analog.contains("hog") || analog.contains("ram")
        let robot = analog.contains("bot") || analog.contains("droid") || analog.contains("drone") ||
            analog.contains("cart") || analog.contains("sparky") || analog.contains("tesla")
        let stone = analog.contains("golem") || analog.contains("giant") || analog.contains("bowler")
        let spirit = analog.contains("spirit") || analog.contains("fire")
        let mage = analog.contains("witch") || analog.contains("wizard") || analog.contains("mage")
        let archer = analog.contains("archer") || analog.contains("musketeer") || analog.contains("dart") ||
            analog.contains("hunter") || analog.contains("executioner")
        let bulky = card.hp > 1500 || card.behavior.contains(.buildingTarget)
        let headSize = skeleton ? 0.30 : (bulky ? 0.33 : 0.29)
        let bodyWidth = w * (bulky ? 0.70 : (spirit ? 0.55 : 0.60))
        let bodyHeight = h * (bulky ? 0.47 : (spirit ? 0.42 : 0.50))

        func shape(_ points: [CGPoint], _ fill: UIColor, _ stroke: UIColor = outline, _ line: CGFloat = 2) -> SKShapeNode {
            let path = CGMutablePath()
            guard let first = points.first else { return SKShapeNode() }
            path.move(to: first)
            for p in points.dropFirst() { path.addLine(to: p) }
            path.closeSubpath()
            let node = SKShapeNode(path: path)
            node.fillColor = fill; node.strokeColor = stroke; node.lineWidth = line; node.lineJoin = .round
            root.addChild(node)
            return node
        }
        func ellipse(_ rect: CGRect, _ fill: UIColor, _ stroke: UIColor = outline, _ line: CGFloat = 2, z: CGFloat = 0) -> SKShapeNode {
            let node = SKShapeNode(ellipseIn: rect)
            node.fillColor = fill; node.strokeColor = stroke; node.lineWidth = line; node.zPosition = z
            root.addChild(node)
            return node
        }
        func rect(_ rect: CGRect, _ radius: CGFloat, _ fill: UIColor, _ stroke: UIColor = outline, _ line: CGFloat = 2, z: CGFloat = 0) -> SKShapeNode {
            let node = SKShapeNode(rect: rect, cornerRadius: radius)
            node.fillColor = fill; node.strokeColor = stroke; node.lineWidth = line; node.zPosition = z
            root.addChild(node)
            return node
        }

        // The oval team badge remains visible at tiny in-game scale; flyers hover above it.
        let badge = ellipse(CGRect(x: -w * 0.43, y: -h * 0.48, width: w * 0.86, height: h * 0.20),
                            teamColor.withAlphaComponent(0.92), teamColor, 1.1, z: -8)
        badge.glowWidth = 0
        if flying {
            badge.xScale = 0.72
            let shadow = ellipse(CGRect(x: -w * 0.30, y: -h * 0.65, width: w * 0.60, height: h * 0.14),
                                 UIColor.black.withAlphaComponent(0.30), .clear, 0, z: -9)
            shadow.alpha = 0.7
        }

        let cardShapeStartIndex = root.children.count
        if card.kind == .spell {
            if analog.contains("zap") || analog.contains("lightning") {
                shape([CGPoint(x:-w*0.02,y:h*0.48),CGPoint(x:-w*0.30,y:h*0.02),CGPoint(x:-w*0.06,y:h*0.02),
                       CGPoint(x:-w*0.18,y:-h*0.46),CGPoint(x:w*0.30,y:h*0.08),CGPoint(x:w*0.06,y:h*0.08)], .systemYellow, outline, 2.5)
            } else if analog.contains("barrel") || analog.contains("log") {
                rect(CGRect(x:-w*0.30,y:-h*0.30,width:w*0.60,height:h*0.60), w*0.12,
                     UIColor(red:0.48,green:0.27,blue:0.12,alpha:1), outline, 2.3)
                for row in [-0.18,0.02,0.22] {
                    rect(CGRect(x:-w*0.32,y:CGFloat(row)*h,width:w*0.64,height:h*0.045), w*0.02, .systemYellow, outline, 1.2)
                }
                if analog.contains("goblin") || analog.contains("skeleton") {
                    shape([CGPoint(x:-w*0.24,y:h*0.20),CGPoint(x:-w*0.48,y:h*0.42),CGPoint(x:-w*0.16,y:h*0.36)], trim, outline, 1.5)
                    shape([CGPoint(x:w*0.24,y:h*0.20),CGPoint(x:w*0.48,y:h*0.42),CGPoint(x:w*0.16,y:h*0.36)], trim, outline, 1.5)
                }
            } else if analog.contains("snow") || analog.contains("freeze") {
                shape([CGPoint(x:0,y:h*0.48),CGPoint(x:w*0.22,y:h*0.18),CGPoint(x:w*0.44,y:0),
                       CGPoint(x:w*0.22,y:-h*0.18),CGPoint(x:0,y:-h*0.48),CGPoint(x:-w*0.22,y:-h*0.18),
                       CGPoint(x:-w*0.44,y:0),CGPoint(x:-w*0.22,y:h*0.18)], .systemCyan, outline, 2.2)
                for angle in [CGFloat(0),CGFloat.pi/3,CGFloat.pi*2/3] {
                    let ray = SKShapeNode()
                    let path = CGMutablePath(); path.move(to: CGPoint(x:-cos(angle)*w*0.28,y:-sin(angle)*h*0.28))
                    path.addLine(to: CGPoint(x:cos(angle)*w*0.28,y:sin(angle)*h*0.28))
                    ray.path = path; ray.strokeColor = .white; ray.lineWidth = 1.6; root.addChild(ray)
                }
            } else if analog.contains("arrow") || analog.contains("volley") {
                for index in 0..<3 {
                    let x = CGFloat(index-1)*w*0.22
                    shape([CGPoint(x:x,y:h*0.40),CGPoint(x:x-w*0.09,y:h*0.15),CGPoint(x:x-w*0.035,y:h*0.18),
                           CGPoint(x:x-w*0.035,y:-h*0.36),CGPoint(x:x+w*0.035,y:-h*0.36),
                           CGPoint(x:x+w*0.035,y:h*0.18),CGPoint(x:x+w*0.09,y:h*0.15)], .lightGray, outline, 1.4)
                }
            } else if analog.contains("tornado") || analog.contains("cyclone") {
                for index in 0..<4 {
                    let swirl = SKShapeNode(); let path = CGMutablePath()
                    let width = w * (0.45 - CGFloat(index)*0.07)
                    path.move(to: CGPoint(x:-width,y:-h*0.30+CGFloat(index)*h*0.16))
                    path.addQuadCurve(to: CGPoint(x:width,y:-h*0.30+CGFloat(index)*h*0.16),
                                      control: CGPoint(x:0,y:h*0.42-CGFloat(index)*h*0.08))
                    swirl.path = path; swirl.strokeColor = index.isMultiple(of:2) ? .white : .systemCyan
                    swirl.lineWidth = 2.1; root.addChild(swirl)
                }
            } else if analog.contains("earthquake") || analog.contains("quake") {
                shape([CGPoint(x:-w*0.48,y:-h*0.20),CGPoint(x:-w*0.25,y:-h*0.02),CGPoint(x:-w*0.12,y:-h*0.30),
                       CGPoint(x:w*0.02,y:h*0.10),CGPoint(x:w*0.19,y:-h*0.12),CGPoint(x:w*0.42,y:h*0.28)], .systemOrange, outline, 2.4)
            } else if analog.contains("fireball") || analog.contains("fire") {
                shape([CGPoint(x:0,y:-h*0.45),CGPoint(x:-w*0.38,y:-h*0.04),CGPoint(x:-w*0.30,y:h*0.26),
                       CGPoint(x:0,y:h*0.48),CGPoint(x:w*0.30,y:h*0.24),CGPoint(x:w*0.40,y:-h*0.08)], .systemOrange, outline, 2.4)
                shape([CGPoint(x:0,y:-h*0.24),CGPoint(x:-w*0.16,y:0),CGPoint(x:0,y:h*0.30),CGPoint(x:w*0.18,y:0)], .systemYellow, outline, 1.5)
            } else if analog.contains("rage") || analog.contains("poison") {
                rect(CGRect(x:-w*0.22,y:-h*0.30,width:w*0.44,height:h*0.52), w*0.08,
                     analog.contains("rage") ? .systemPurple : .systemGreen, outline, 2.2)
                rect(CGRect(x:-w*0.11,y:h*0.20,width:w*0.22,height:h*0.14), w*0.03, trim, outline, 1.5)
                ellipse(CGRect(x:-w*0.10,y:-h*0.08,width:w*0.20,height:h*0.20), .white.withAlphaComponent(0.65), outline, 1)
            } else if analog.contains("graveyard") {
                shape([CGPoint(x:-w*0.32,y:-h*0.40),CGPoint(x:-w*0.32,y:h*0.10),CGPoint(x:-w*0.20,y:h*0.35),
                       CGPoint(x:w*0.20,y:h*0.35),CGPoint(x:w*0.32,y:h*0.10),CGPoint(x:w*0.32,y:-h*0.40)], .darkGray, outline, 2.4)
                for side in [-1.0,1.0] {
                    shape([CGPoint(x:CGFloat(side)*w*0.12,y:-h*0.32),CGPoint(x:CGFloat(side)*w*0.28,y:-h*0.08),
                           CGPoint(x:CGFloat(side)*w*0.18,y:h*0.04)], UIColor(white:0.90,alpha:1), outline, 1.5)
                }
            } else if analog.contains("rocket") {
                shape([CGPoint(x:0,y:h*0.48),CGPoint(x:-w*0.22,y:h*0.10),CGPoint(x:-w*0.18,y:-h*0.25),
                       CGPoint(x:w*0.18,y:-h*0.25),CGPoint(x:w*0.22,y:h*0.10)], .lightGray, outline, 2.4)
                shape([CGPoint(x:-w*0.18,y:-h*0.14),CGPoint(x:-w*0.42,y:-h*0.42),CGPoint(x:-w*0.13,y:-h*0.32)], .systemRed, outline, 1.5)
                shape([CGPoint(x:w*0.18,y:-h*0.14),CGPoint(x:w*0.42,y:-h*0.42),CGPoint(x:w*0.13,y:-h*0.32)], .systemRed, outline, 1.5)
            } else {
                shape([CGPoint(x:0,y:h*0.48),CGPoint(x:w*0.36,y:h*0.08),CGPoint(x:w*0.18,y:-h*0.42),
                       CGPoint(x:-w*0.18,y:-h*0.42),CGPoint(x:-w*0.36,y:h*0.08)], trim, outline, 2.4)
                ellipse(CGRect(x:-w*0.10,y:-h*0.08,width:w*0.20,height:h*0.20), .systemCyan, .white, 1.2)
            }
            return root
        }

        if card.kind == .building {
            let base = CGRect(x:-w*0.34,y:-h*0.34,width:w*0.68,height:h*0.62)
            switch index % 11 {
            case 0:
                rect(base,w*0.10,trim,outline,2.4)
                ellipse(CGRect(x:-w*0.40,y:-h*0.36,width:w*0.22,height:h*0.22),.darkGray,outline,1.8)
                ellipse(CGRect(x:w*0.18,y:-h*0.36,width:w*0.22,height:h*0.22),.darkGray,outline,1.8)
                rect(CGRect(x:-w*0.05,y:h*0.02,width:w*0.48,height:h*0.16),w*0.07,.darkGray,outline,2.2).zRotation = 0.35
            case 1:
                shape([CGPoint(x:-w*0.34,y:-h*0.34),CGPoint(x:-w*0.34,y:h*0.10),CGPoint(x:-w*0.20,y:h*0.34),
                       CGPoint(x:w*0.20,y:h*0.34),CGPoint(x:w*0.34,y:h*0.10),CGPoint(x:w*0.34,y:-h*0.34)],trim,outline,2.4)
                ellipse(CGRect(x:-w*0.10,y:-h*0.02,width:w*0.20,height:h*0.20),.white,outline,1.4)
            case 2:
                rect(base,w*0.08,.darkGray,outline,2.4)
                shape([CGPoint(x:-w*0.40,y:h*0.18),CGPoint(x:-w*0.25,y:h*0.43),CGPoint(x:w*0.25,y:h*0.43),CGPoint(x:w*0.40,y:h*0.18)],trim,outline,2.2)
                ellipse(CGRect(x:-w*0.16,y:-h*0.02,width:w*0.32,height:h*0.32),.black,outline,2)
            case 3,7:
                shape([CGPoint(x:-w*0.38,y:-h*0.35),CGPoint(x:-w*0.25,y:h*0.18),CGPoint(x:0,y:h*0.48),
                       CGPoint(x:w*0.25,y:h*0.18),CGPoint(x:w*0.38,y:-h*0.35)],trim,outline,2.4)
                for row in 0..<3 { ellipse(CGRect(x:-w*0.20+CGFloat(row)*w*0.04,y:-h*0.12+CGFloat(row)*h*0.15,
                                                  width:w*0.40-CGFloat(row)*w*0.08,height:h*0.12),.systemCyan,outline,1.5) }
            case 4:
                rect(base,w*0.10,UIColor(red:0.34,green:0.25,blue:0.19,alpha:1),outline,2.4)
                shape([CGPoint(x:-w*0.24,y:-h*0.10),CGPoint(x:-w*0.14,y:h*0.16),CGPoint(x:0,y:h*0.04),
                       CGPoint(x:w*0.12,y:h*0.28),CGPoint(x:w*0.25,y:-h*0.10)],.systemOrange,outline,2)
            case 5:
                rect(base,w*0.12,trim,outline,2.4)
                ellipse(CGRect(x:-w*0.32,y:-h*0.02,width:w*0.64,height:h*0.42),.darkGray,outline,2.2).zRotation = 0.25
                ellipse(CGRect(x:-w*0.13,y:h*0.17,width:w*0.26,height:h*0.12),.black,outline,1.4)
            case 6,10:
                shape([CGPoint(x:-w*0.46,y:-h*0.34),CGPoint(x:-w*0.46,y:h*0.10),CGPoint(x:0,y:h*0.48),
                       CGPoint(x:w*0.46,y:h*0.10),CGPoint(x:w*0.46,y:-h*0.34)],trim,outline,2.4)
                rect(CGRect(x:-w*0.11,y:-h*0.34,width:w*0.22,height:h*0.32),w*0.04,.brown,outline,1.8)
            case 8:
                rect(base,w*0.08,trim,outline,2.4)
                shape([CGPoint(x:-w*0.48,y:h*0.20),CGPoint(x:-w*0.30,y:h*0.34),CGPoint(x:0,y:-h*0.02),
                       CGPoint(x:w*0.30,y:h*0.34),CGPoint(x:w*0.48,y:h*0.20)],.lightGray,outline,2.4)
            default:
                rect(base,w*0.09,.darkGray,outline,2.4)
                rect(CGRect(x:-w*0.24,y:-h*0.16,width:w*0.48,height:h*0.48),w*0.08,.systemTeal,outline,2.2)
            }
            if root.children.indices.contains(cardShapeStartIndex) { root.children[cardShapeStartIndex].name = "body" }
            let turret = SKNode(); turret.name = "turret"; root.addChild(turret)
            let barrel = SKShapeNode(rectOf: CGSize(width:w*0.10,height:h*0.36),cornerRadius:w*0.04)
            barrel.position = CGPoint(x:w*0.02,y:h*0.14); barrel.fillColor = .lightGray; barrel.strokeColor = outline
            barrel.lineWidth = 1.8; turret.addChild(barrel)
            return root
        }

        if spirit {
            let flame = shape([
                CGPoint(x: 0, y: -h * 0.32), CGPoint(x: -w * 0.27, y: -h * 0.04),
                CGPoint(x: -w * 0.20, y: h * 0.25), CGPoint(x: 0, y: h * 0.42),
                CGPoint(x: w * 0.22, y: h * 0.20), CGPoint(x: w * 0.28, y: -h * 0.05)
            ], coat, outline, 2.2)
            flame.zPosition = 2
            ellipse(CGRect(x: -w * 0.13, y: -h * 0.04, width: w * 0.26, height: h * 0.22), .systemYellow, outline, 1.2, z: 3)
            ellipse(CGRect(x: -w * 0.075, y: h * 0.06, width: w * 0.055, height: h * 0.07), outline, .clear, 0, z: 4)
            ellipse(CGRect(x: w * 0.02, y: h * 0.06, width: w * 0.055, height: h * 0.07), outline, .clear, 0, z: 4)
            return root
        }

        if flying {
            if dragon {
                shape([CGPoint(x: -w*0.20,y: h*0.02),CGPoint(x: -w*0.55,y: h*0.38),CGPoint(x: -w*0.42,y: -h*0.28),CGPoint(x: -w*0.08,y: -h*0.08)], trim, outline, 2.1).zPosition = -1
                shape([CGPoint(x: w*0.20,y: h*0.02),CGPoint(x: w*0.55,y: h*0.38),CGPoint(x: w*0.42,y: -h*0.28),CGPoint(x: w*0.08,y: -h*0.08)], trim, outline, 2.1).zPosition = -1
            } else {
                ellipse(CGRect(x: -w*0.57,y: -h*0.05,width: w*0.48,height: h*0.38), coat, outline, 1.8, z: -1).zRotation = 0.38
                ellipse(CGRect(x: w*0.09,y: -h*0.05,width: w*0.48,height: h*0.38), coat, outline, 1.8, z: -1).zRotation = -0.38
                shape([CGPoint(x:-w*0.48,y:h*0.12),CGPoint(x:-w*0.22,y:h*0.38),CGPoint(x:-w*0.18,y:h*0.03)], .white.withAlphaComponent(0.7), outline, 1)
                shape([CGPoint(x:w*0.48,y:h*0.12),CGPoint(x:w*0.22,y:h*0.38),CGPoint(x:w*0.18,y:h*0.03)], .white.withAlphaComponent(0.7), outline, 1)
            }
        }

        // Distinct body profiles: armor plate, robe, broad brute, insect abdomen or narrow scout.
        let bodyRect = CGRect(x: -bodyWidth/2, y: -h*0.34, width: bodyWidth, height: bodyHeight)
        let bodyStartIndex = root.children.count
        switch index % 6 {
        case 0:
            shape([CGPoint(x:-bodyWidth*0.50,y:-h*0.31),CGPoint(x:-bodyWidth*0.42,y:h*0.06),CGPoint(x:-bodyWidth*0.22,y:h*0.20),CGPoint(x:bodyWidth*0.22,y:h*0.20),CGPoint(x:bodyWidth*0.42,y:h*0.06),CGPoint(x:bodyWidth*0.50,y:-h*0.31)], coat, outline, 2.2)
        case 1:
            shape([CGPoint(x:-bodyWidth*0.48,y:h*0.12),CGPoint(x:bodyWidth*0.48,y:h*0.12),CGPoint(x:bodyWidth*0.62,y:-h*0.35),CGPoint(x:-bodyWidth*0.62,y:-h*0.35)], coat, outline, 2.2)
        case 2:
            rect(bodyRect, w*0.16, coat, outline, 2.2)
        case 3:
            shape([CGPoint(x:0,y:h*0.20),CGPoint(x:bodyWidth*0.52,y:-h*0.02),CGPoint(x:bodyWidth*0.42,y:-h*0.35),CGPoint(x:-bodyWidth*0.42,y:-h*0.35),CGPoint(x:-bodyWidth*0.52,y:-h*0.02)], coat, outline, 2.2)
        case 4:
            ellipse(CGRect(x:-bodyWidth*0.50,y:-h*0.33,width:bodyWidth,height:bodyHeight), coat, outline, 2.2, z: 1)
        default:
            shape([CGPoint(x:-bodyWidth*0.40,y:h*0.16),CGPoint(x:bodyWidth*0.40,y:h*0.16),CGPoint(x:bodyWidth*0.58,y:-h*0.12),CGPoint(x:bodyWidth*0.22,y:-h*0.37),CGPoint(x:-bodyWidth*0.22,y:-h*0.37),CGPoint(x:-bodyWidth*0.58,y:-h*0.12)], coat, outline, 2.2)
        }
        if root.children.indices.contains(bodyStartIndex) { root.children[bodyStartIndex].name = "body" }
        if let body = root.childNode(withName: "body") {
            body.run(.repeatForever(.sequence([.scaleY(to: 0.96, duration: 0.38), .scaleY(to: 1.02, duration: 0.38)])), withKey: "idle-breathe")
        }
        // Team sash and bright card trim never replace the card's own palette.
        shape([CGPoint(x:-bodyWidth*0.44,y:h*0.04),CGPoint(x:bodyWidth*0.44,y:h*0.04),CGPoint(x:bodyWidth*0.30,y:-h*0.12),CGPoint(x:-bodyWidth*0.30,y:-h*0.12)], teamColor, outline, 1.4).zPosition = 3
        if robot || stone {
            rect(CGRect(x:-bodyWidth*0.37,y:-h*0.23,width:bodyWidth*0.74,height:h*0.20), w*0.045, trim, outline, 1.8, z: 4)
            for side in [-1.0,1.0] { ellipse(CGRect(x:CGFloat(side)*bodyWidth*0.19-w*0.045,y:-h*0.18,width:w*0.09,height:h*0.09), .systemCyan, outline, 1, z:5) }
        } else if skeleton {
            for rib in 0..<3 {
                let y = -h*0.03 - CGFloat(rib)*h*0.07
                let ribPath = CGMutablePath(); ribPath.move(to: CGPoint(x:-bodyWidth*0.28,y:y)); ribPath.addQuadCurve(to: CGPoint(x:bodyWidth*0.28,y:y), control: CGPoint(x:0,y:y-h*0.13))
                let bone = SKShapeNode(path: ribPath); bone.strokeColor = UIColor(white:0.94,alpha:1); bone.lineWidth = 2.2; root.addChild(bone)
            }
        }

        // Head and face are deliberately oversized for recognition on a phone.
        let headY = h * 0.30
        if robot {
            rect(CGRect(x:-w*headSize,y:headY-h*0.04,width:w*headSize*2,height:h*0.31), w*0.06, trim, outline, 2.2, z:6)
            rect(CGRect(x:-w*0.19,y:headY+h*0.045,width:w*0.38,height:h*0.075), w*0.035, .systemCyan, outline, 1, z:7)
        } else if skeleton {
            ellipse(CGRect(x:-w*headSize,y:headY-h*0.03,width:w*headSize*2,height:h*0.29), UIColor(white:0.91,alpha:1), outline, 2.1, z:6)
            shape([CGPoint(x:-w*0.22,y:headY-h*0.12),CGPoint(x:-w*0.08,y:headY-h*0.18),CGPoint(x:0,y:headY-h*0.12),CGPoint(x:w*0.08,y:headY-h*0.18),CGPoint(x:w*0.22,y:headY-h*0.12)], .clear, outline, 1.3).zPosition = 7
        } else if dragon || hog {
            ellipse(CGRect(x:-w*headSize*1.1,y:headY-h*0.01,width:w*headSize*2.2,height:h*0.25), skin, outline, 2.2, z:6)
            shape([CGPoint(x:w*0.08,y:headY-h*0.02),CGPoint(x:w*0.36,y:headY+h*0.03),CGPoint(x:w*0.12,y:headY-h*0.13)], trim, outline, 1.5).zPosition = 7
        } else {
            switch index % 4 {
            case 0: ellipse(CGRect(x:-w*headSize,y:headY-h*0.02,width:w*headSize*2,height:h*0.29), skin, outline, 2.2, z:6)
            case 1: rect(CGRect(x:-w*headSize,y:headY-h*0.02,width:w*headSize*2,height:h*0.29), w*0.07, skin, outline, 2.2, z:6)
            case 2: shape([CGPoint(x:-w*headSize,y:headY-h*0.04),CGPoint(x:0,y:headY+h*0.28),CGPoint(x:w*headSize,y:headY-h*0.04),CGPoint(x:0,y:headY-h*0.12)], skin, outline, 2.2).zPosition = 6
            default: ellipse(CGRect(x:-w*headSize*1.1,y:headY-h*0.02,width:w*headSize*2.2,height:h*0.29), skin, outline, 2.2, z:6)
            }
        }
        // Eye dots and cheek/visor highlight are high contrast at the minimum sprite size.
        for side in [-1.0,1.0] {
            ellipse(CGRect(x:CGFloat(side)*w*0.105-w*0.025,y:headY+h*0.075,width:w*0.05,height:h*0.065),
                    robot ? .systemYellow : outline, .clear, 0, z:8)
        }
        let mouth = SKShapeNode(rectOf: CGSize(width:w*0.16,height:h*0.025), cornerRadius: 1)
        mouth.position = CGPoint(x:0,y:headY-h*0.005); mouth.fillColor = outline; mouth.strokeColor = .clear; mouth.zPosition = 8; root.addChild(mouth)

        // Card identity details: horn/crown/helmet/hood/mohawk/antenna/hat/cap.
        let top = headY + h*0.24
        switch index % 8 {
        case 0:
            shape([CGPoint(x:-w*0.24,y:top-h*0.12),CGPoint(x:-w*0.38,y:top+h*0.10),CGPoint(x:-w*0.10,y:top-h*0.01)], trim, outline, 1.8)
            shape([CGPoint(x:w*0.24,y:top-h*0.12),CGPoint(x:w*0.38,y:top+h*0.10),CGPoint(x:w*0.10,y:top-h*0.01)], trim, outline, 1.8)
        case 1:
            shape([CGPoint(x:-w*0.29,y:top-h*0.06),CGPoint(x:-w*0.18,y:top+h*0.14),CGPoint(x:0,y:top+h*0.02),CGPoint(x:w*0.18,y:top+h*0.14),CGPoint(x:w*0.29,y:top-h*0.06)], trim, outline, 1.8)
        case 2:
            ellipse(CGRect(x:-w*0.33,y:top-h*0.07,width:w*0.66,height:h*0.13), coat, outline, 1.8, z:9)
            shape([CGPoint(x:-w*0.18,y:top),CGPoint(x:0,y:top+h*0.20),CGPoint(x:w*0.18,y:top)], trim, outline, 1.6).zPosition = 10
        case 3:
            rect(CGRect(x:-w*0.32,y:top-h*0.07,width:w*0.64,height:h*0.15), w*0.05, trim, outline, 1.8, z:9)
        case 4:
            shape([CGPoint(x:-w*0.29,y:top-h*0.08),CGPoint(x:-w*0.20,y:top+h*0.18),CGPoint(x:w*0.20,y:top+h*0.18),CGPoint(x:w*0.29,y:top-h*0.08)], coat, outline, 2).zPosition = 9
        case 5:
            ellipse(CGRect(x:-w*0.35,y:top-h*0.04,width:w*0.70,height:h*0.12), trim, outline, 1.8, z:9)
            rect(CGRect(x:-w*0.09,y:top+h*0.02,width:w*0.18,height:h*0.15), w*0.03, coat, outline, 1.4, z:10)
        case 6:
            for side in [-1.0,1.0] {
                shape([CGPoint(x:CGFloat(side)*w*0.16,y:top-h*0.03),CGPoint(x:CGFloat(side)*w*0.30,y:top+h*0.19),CGPoint(x:CGFloat(side)*w*0.10,y:top+h*0.08)], trim, outline, 1.6).zPosition = 9
            }
        default:
            shape([CGPoint(x:-w*0.28,y:top-h*0.05),CGPoint(x:-w*0.17,y:top+h*0.09),CGPoint(x:w*0.17,y:top+h*0.09),CGPoint(x:w*0.28,y:top-h*0.05)], trim, outline, 1.8).zPosition = 9
        }

        // Short articulated legs and a pivoting forearm make movement and swings readable.
        for (name, side) in [("leg-left", -1.0), ("leg-right", 1.0)] {
            let leg = SKNode(); leg.name = name
            leg.position = CGPoint(x: CGFloat(side) * bodyWidth * 0.22, y: -h * 0.28)
            leg.zPosition = -2
            let shin = SKShapeNode(rectOf: CGSize(width: w * 0.16, height: h * 0.25), cornerRadius: w * 0.035)
            shin.fillColor = trim; shin.strokeColor = outline; shin.lineWidth = 1.8
            leg.addChild(shin)
            let boot = SKShapeNode(ellipseOf: CGSize(width: w * 0.22, height: h * 0.10))
            boot.position = CGPoint(x: w * 0.035, y: -h * 0.12)
            boot.fillColor = teamColor; boot.strokeColor = outline; boot.lineWidth = 1.3
            leg.addChild(boot)
            root.addChild(leg)
        }
        let weaponArm = SKNode()
        weaponArm.name = "weapon-arm"
        weaponArm.position = CGPoint(x: bodyWidth * 0.40, y: -h * 0.02)
        weaponArm.zPosition = 6
        let forearm = SKShapeNode(rectOf: CGSize(width: w * 0.15, height: h * 0.34), cornerRadius: w * 0.06)
        forearm.position = CGPoint(x: w * 0.04, y: -h * 0.04)
        forearm.fillColor = teamColor; forearm.strokeColor = outline; forearm.lineWidth = 1.7
        weaponArm.addChild(forearm)
        root.addChild(weaponArm)

        // Weapons are drawn as a hand-held object with a distinctive profile.
        let weaponX = w * 0.34, weaponY = -h * 0.03
        if card.behavior.contains(.ranged) || mage || archer {
            let shaft = rect(CGRect(x:weaponX-w*0.045,y:weaponY-h*0.18,width:w*0.09,height:h*0.64), w*0.025, trim, outline, 1.5, z:11)
            shaft.zRotation = -0.20
            if analog.contains("bow") || analog.contains("archer") {
                let bow = SKShapeNode()
                let path = CGMutablePath(); path.move(to: CGPoint(x:weaponX-w*0.10,y:weaponY-h*0.20)); path.addQuadCurve(to: CGPoint(x:weaponX-w*0.10,y:weaponY+h*0.30), control: CGPoint(x:weaponX+w*0.30,y:weaponY+h*0.05))
                bow.path = path; bow.strokeColor = .white; bow.lineWidth = 2; root.addChild(bow)
            } else {
                ellipse(CGRect(x:weaponX-w*0.11,y:weaponY+h*0.20,width:w*0.22,height:h*0.14), .systemYellow, outline, 1.4, z:12)
            }
        } else {
            let blade = shape([CGPoint(x:weaponX-w*0.07,y:weaponY-h*0.22),CGPoint(x:weaponX+w*0.08,y:weaponY-h*0.22),
                               CGPoint(x:weaponX+w*0.11,y:weaponY+h*0.27),CGPoint(x:weaponX,y:weaponY+h*0.43),
                               CGPoint(x:weaponX-w*0.11,y:weaponY+h*0.27)], .lightGray, outline, 1.8)
            blade.zPosition = 11
            rect(CGRect(x:weaponX-w*0.16,y:weaponY-h*0.08,width:w*0.32,height:h*0.055), w*0.02, trim, outline, 1.1, z:12)
        }
        if card.behavior.contains(.shield) || analog.contains("guard") || analog.contains("recruit") {
            shape([CGPoint(x:-w*0.43,y:h*0.10),CGPoint(x:-w*0.17,y:h*0.20),CGPoint(x:-w*0.19,y:-h*0.19),
                   CGPoint(x:-w*0.38,y:-h*0.30),CGPoint(x:-w*0.49,y:-h*0.12)], trim, outline, 2).zPosition = 13
        }
        if hog {
            ellipse(CGRect(x:-w*0.40,y:-h*0.32,width:w*0.80,height:h*0.30), skin, outline, 2, z:12)
            ellipse(CGRect(x:w*0.12,y:-h*0.25,width:w*0.22,height:h*0.13), UIColor(red:0.85,green:0.42,blue:0.38,alpha:1), outline, 1.3, z:13)
        }
        if dragon {
            shape([CGPoint(x:-w*0.16,y:h*0.13),CGPoint(x:-w*0.42,y:h*0.38),CGPoint(x:-w*0.25,y:-h*0.01)], trim, outline, 1.5).zPosition = 12
            shape([CGPoint(x:w*0.16,y:h*0.13),CGPoint(x:w*0.42,y:h*0.38),CGPoint(x:w*0.25,y:-h*0.01)], trim, outline, 1.5).zPosition = 12
        }
        if bulky {
            for side in [-1.0,1.0] {
                ellipse(CGRect(x:CGFloat(side)*bodyWidth*0.36-w*0.09,y:h*0.02,width:w*0.18,height:h*0.22), trim, outline, 1.5, z:5)
            }
        }
        return root
    }
}
