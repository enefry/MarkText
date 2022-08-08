//
//  ViewController.swift
//  MarkText
//
//  Created by renwei.chen on 2022/7/12.
//

import MBProgressHUD
import Photos
import PhotosUI
import UIKit

class ViewController: UIViewController, UICollectionViewDataSource, PHPickerViewControllerDelegate, UICollectionViewDelegate {
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var prefixTextField: UITextField!
    @IBOutlet var selectedSuffixTextField: UITextField!
    @IBOutlet var unselectedSuffixTextField: UITextField!
    @IBOutlet var autoIndex: UISwitch!
    @IBOutlet var multiPrefix: UISwitch!
    var selectedItems:[IndexPath] = []
    var images: [UIImage] = []
    var renderImages: [UIImage] = []
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        images = []
        renderImages = []
        collectionView.reloadData()
        results.forEach { item in
            if item.itemProvider.canLoadObject(ofClass: UIImage.self) {
                item.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                    if let self = self, let image = image as? UIImage {
                        self.addImage(image: image)
                    }
                }
            }
        }
        picker.dismiss(animated: true)
    }
    
    func addImage(image: UIImage) {
        DispatchQueue.main.async {
            self.images.append(image)
            self.renderImages.append(image)
            self.collectionView.reloadData()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return renderImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        if let iv = (cell.viewWithTag(100) as? UIImageView) {
            iv.image = renderImages[indexPath.item]
        }
        return cell
    }
    
    /// 格子布局
    internal let gridLayout: UICollectionViewLayout = {
        UICollectionViewCompositionalLayout { section, environment in
            let size = environment.container.effectiveContentSize
            var widthDimension: NSCollectionLayoutDimension = .fractionalWidth(0.5)
            var heightDimension: NSCollectionLayoutDimension = .fractionalWidth(0.7)
            let itemSize = NSCollectionLayoutSize(widthDimension: widthDimension,
                                                  heightDimension: .fractionalHeight(1.0))
            var item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: heightDimension)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                           subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.boundarySupplementaryItems = [
                NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)), elementKind: UICollectionView.elementKindSectionFooter, alignment: .bottom), /* loading view*/
                NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(51)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .top), /* search bar */
            ]
            return section
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.collectionViewLayout = gridLayout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = true
        prefixTextField.text = UserDefaults.standard.string(forKey: "prefix") ?? "(班级)-(姓名)"
        selectedSuffixTextField.text = UserDefaults.standard.string(forKey: "selected-suffix") ?? ""
        unselectedSuffixTextField.text = UserDefaults.standard.string(forKey: "unselected-suffix") ?? ""
        autoIndex.isOn = UserDefaults.standard.bool(forKey: "auto-index-on")
        multiPrefix.isOn = UserDefaults.standard.bool(forKey: "multi-prefix")
        
        collectionView.automaticallyAdjustsScrollIndicatorInsets = false
    }
    
    @IBAction func onActionPick() {
        view.endEditing(true)
        presentSystemPicker()
    }
    
    func showHud(title: String) -> MBProgressHUD {
        let hud = {
            if let view = MBProgressHUD.forView(view) {
                return view
            } else {
                return MBProgressHUD(view: view)
            }
        }()
        hud.label.text = title
        view.addSubview(hud)
        hud.show(animated: true)
        return hud
    }
    
    @IBAction func onActionRender() {
        view.endEditing(true)
        let hud = showHud(title: "渲染处理中,请稍后")
        let selectedItem = selectedItems//collectionView.indexPathsForSelectedItems
        let images = images
        let prefixText = prefixTextField.text ?? "(班级)-(姓名)"
        let selectedSuffix = selectedSuffixTextField.text ?? ""
        let unselectedSuffix = unselectedSuffixTextField.text ?? ""
        let autoIndexOn = autoIndex.isOn
        let multiPrefix = multiPrefix.isOn
        UserDefaults.standard.set(prefixText, forKey: "prefix")
        UserDefaults.standard.set(selectedSuffix, forKey: "selected-suffix")
        UserDefaults.standard.set(unselectedSuffix, forKey: "unselected-suffix")
        UserDefaults.standard.set(autoIndexOn, forKey: "auto-index-on")
        UserDefaults.standard.set(autoIndexOn, forKey: "multi-prefix")
        
        DispatchQueue.global().async {
            var prefixs = [prefixText]
            
            var results: [UIImage] = []
            if multiPrefix{
                prefixs = prefixText.split(separator: ";").map({ sub in
                    String(sub)
                })
            }
            
            
            for prefixIndex in 0..<prefixs.count {
                let prefix = prefixs[prefixIndex]
                var selectedIndex = -1
                if selectedItem.count>0
                {
                if selectedItem.count>prefixIndex  {
                    selectedIndex = selectedItem[prefixIndex ].item
                }else{
                    selectedIndex = selectedItem.last?.item ?? -1
                }
                
                }
                results.append(contentsOf:
                                self.render(images: images, selectedItem: selectedIndex  , prefix: prefix, selectedSuffix: selectedSuffix, unselectedSuffix: unselectedSuffix, autoIndexOn: autoIndexOn)
                )
            }
            DispatchQueue.main.async {
                self.renderImages = results
                self.collectionView.reloadData()
                hud.hide(animated: true, afterDelay: 0.5)
            }
        }
    }
    
    func render(images:[UIImage],selectedItem:Int,prefix:String,selectedSuffix:String,unselectedSuffix:String,autoIndexOn:Bool )->[UIImage]{
        var count = 0
        var results: [UIImage] = []
        for idx in 0 ..< images.count {
            let img = images[idx]
            let text: String = {
                if idx == selectedItem {
                    return "\(prefix)\(selectedSuffix)"
                } else {
                    if autoIndexOn {
                        count = count + 1
                        return "\(prefix)\(unselectedSuffix)\(count)"
                    } else {
                        return "\(prefix)\(unselectedSuffix)"
                    }
                }
            }()
            
            let fontSize = (img.size.width / 20)
            let font = UIFont.boldSystemFont(ofSize: fontSize)
            let attribute = [NSAttributedString.Key.font: font]
            let textSize = (text as NSString).size(withAttributes: attribute)
            UIGraphicsBeginImageContext(img.size)
            img.draw(at: CGPoint.zero)
            UIColor(white: 1, alpha: 0.8).setFill()
            let x = (img.size.width - textSize.width - 10) / 2
            let y = (img.size.height - textSize.height) * 0.6
            let background = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: textSize.width + (fontSize * 2), height: textSize.height + fontSize), cornerRadius: fontSize)
            background.fill()
            UIColor.black.setStroke()
            (text as NSString).draw(at: CGPoint(x: x + fontSize, y: y + fontSize * 0.5), withAttributes: attribute)
            if let result = UIGraphicsGetImageFromCurrentImageContext() {
                results.append(result)
            }
        }
        return results;
    }
    
    @IBAction func onActionSave() {
        view.endEditing(true)
        let hud = showHud(title: "图片保存请稍后")
        PHPhotoLibrary.shared().performChanges {
            self.renderImages.forEach { image in
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            DispatchQueue.main.async {
                hud.hide(animated: true, afterDelay: 0.5)
            }
        }
    }
    
    func presentSystemPicker() {
        var configure = PHPickerConfiguration(photoLibrary: .shared())
        configure.selectionLimit = 12
        let picker = PHPickerViewController(configuration: configure)
        picker.delegate = self
        
        present(picker, animated: true)
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedItems.append(indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        selectedItems.removeAll { idx in
            idx.item == indexPath.item
        }
    }
}

