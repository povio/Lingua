import Foundation

public enum Command: String {
  case ios
  case android
  case config
  case initializer = "init"
  case version = "--version"
  case abbreviatedVersion = "-v"
  case sections
  case list
  case find
  case add
  case update
  case delete
  case sync
  case doctor
  case help
  case helpFlag = "--help"
  case helpShort = "-h"
  case ai
  case install
  case uninstall
  case status
}
