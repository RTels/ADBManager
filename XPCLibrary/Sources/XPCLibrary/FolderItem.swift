//
//  FolderItem.swift
//  XPCLibrary
//

import Foundation

public enum FolderItem: Identifiable, Hashable, Sendable {  
    case folder(name: String, photoCount: Int)
    case photo(name: String)
    
    public var id: String {
        switch self {
        case .folder(let name, _):
            return "folder_\(name)"
        case .photo(let name):
            return "photo_\(name)"
        }
    }
    
    public var name: String {
        switch self {
        case .folder(let name, _), .photo(let name):
            return name
        }
    }
    
    public var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}
