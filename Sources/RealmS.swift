//
//  RealmS.swift
//  RealmS
//
//  Created by DaoNV on 1/10/16.
//  Copyright © 2016 Apple Inc. All rights reserved.
//

import RealmSwift
import Foundation

/**
 A `Realm` instance (also referred to as "a Realm") represents a Realm database.

 Realms can either be stored on disk (see `init(path:)`) or in memory (see `Configuration`).

 `Realm` instances are cached internally, and constructing equivalent `Realm` objects (for example, by using the same
 path or identifier) produces limited overhead.

 If you specifically want to ensure a `Realm` instance is destroyed (for example, if you wish to open a Realm, check
 some property, and then possibly delete the Realm file and re-open it), place the code which uses the Realm within an
 `autoreleasepool {}` and ensure you have no other strong references to it.

 - warning: `Realm` instances are not thread safe and cannot be shared across threads or dispatch queues. You must
 construct a new instance for each thread in which a Realm will be accessed. For dispatch queues, this means
 that you must construct a new instance in each block which is dispatched, as a queue is not guaranteed to
 run all of its blocks on the same thread.
 */
public final class RealmS {

    // MARK: Additional

    public enum ErrorType: Error {
        case write /// throwed while commit write transaction.
        case encrypt /// throwed by `writeCopyToURL(_:, encryptionKey:)`
    }

    public typealias ErrorHandler = (_ realm: RealmS, _ error: NSError, _ type: ErrorType) -> Void

    private static var handleError: ErrorHandler?

    /**
     Invoked after RealmS catched an exception.
     - parameter handler: Error handler block.
     */
    public static func onError(_ handler: @escaping ErrorHandler) {
        handleError = handler
    }

    private var deletedTypes: [Object.Type] = []
    private func clean() {
        while deletedTypes.count > 0 {
            let type = deletedTypes.removeFirst()
            for relatived in type.relativedTypes() {
                relatived.clean()
            }
        }
    }

    // MARK: Properties

    /// The `Schema` used by the Realm.
    public var schema: Schema { return realm.schema }

    /// The `Configuration` value that was used to create the `Realm` instance.
    public var configuration: Realm.Configuration { return realm.configuration }

    /// Indicates if the Realm contains any objects.
    public var isEmpty: Bool { return realm.isEmpty }

    // MARK: Initializers

    /**
     Obtains an instance of the default Realm.

     The default Realm is persisted as *default.realm* under the *Documents* directory of your Application on iOS, and
     in your application's *Application Support* directory on OS X.

     The default Realm is created using the default `Configuration`, which can be changed by setting the
     `Realm.Configuration.defaultConfiguration` property to a new value.

     - throws: An `NSError` if the Realm could not be initialized.
     */
    public convenience init() {
        do {
            let realm = try Realm()
            self.init(realm)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    /**
     Obtains a `Realm` instance with the given configuration.

     - parameter configuration: A configuration value to use when creating the Realm.

     - throws: An `NSError` if the Realm could not be initialized.
     */
    public convenience init(configuration: Realm.Configuration) {
        do {
            let realm = try Realm(configuration: configuration)
            self.init(realm)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    /**
     Obtains a `Realm` instance persisted at a specified file URL.

     - parameter fileURL: The local URL of the file the Realm should be saved at.

     - throws: An `NSError` if the Realm could not be initialized.
     */
    public convenience init!(fileURL: URL) {
        var configuration = Realm.Configuration.defaultConfiguration
        configuration.fileURL = fileURL
        self.init(configuration: configuration)
    }

    // MARK: Transactions

    /**
     Performs actions contained within the given block inside a write transaction.

     If the block throws an error, the transaction will be canceled, reverting any writes made in the block before the
     error was thrown.

     Write transactions cannot be nested, and trying to execute a write transaction on a Realm which is already
     participating in a write transaction will throw an error. Calls to `write` from `Realm` instances in other threads
     will block until the current write transaction completes.

     Before executing the write transaction, `write` updates the `Realm` instance to the latest Realm version, as if
     `refresh()` had been called, and generates notifications if applicable. This has no effect if the Realm was already
     up to date.

     - parameter block: The block containing actions to perform.

     - throws: An `NSError` if the transaction could not be completed successfully.
     If `block` throws, the function throws the propagated `ErrorType` instead.
     */
    public func write(_ block: (() throws -> Void)) {
        do {
            try realm.write(block)
            clean()
        } catch {
            RealmS.handleError?(self, error as NSError, .write)
        }
    }

    /**
     Begins a write transaction on the Realm.

     Only one write transaction can be open at a time. Write transactions cannot be nested, and trying to begin a write
     transaction on a Realm which is already in a write transaction will throw an error. Calls to `beginWrite` from
     `Realm` instances in other threads will block until the current write transaction completes.

     Before beginning the write transaction, `beginWrite` updates the `Realm` instance to the latest Realm version, as
     if `refresh()` had been called, and generates notifications if applicable. This has no effect if the Realm was
     already up to date.

     It is rarely a good idea to have write transactions span multiple cycles of the run loop, but if you do wish to do
     so you will need to ensure that the Realm in the write transaction is kept alive until the write transaction is
     committed.
     */
    public func beginWrite() {
        realm.beginWrite()
    }

    /**
     Commits all write operations in the current write transaction, and ends the transaction.

     - warning: This method may only be called during a write transaction.

     - throws: An `NSError` if the transaction could not be written.
     */
    public func commitWrite() {
        do {
            try realm.commitWrite()
            clean()
        } catch {
            RealmS.handleError?(self, error as NSError, .write)
        }
    }

    /**
     Reverts all writes made in the current write transaction and ends the transaction.

     This rolls back all objects in the Realm to the state they were in at the beginning of the write transaction, and
     then ends the transaction.

     This restores the data for deleted objects, but does not revive invalidated object instances. Any `Object`s which
     were added to the Realm will be invalidated rather than becoming unmanaged.

     Given the following code:

     ```swift
     let oldObject = objects(ObjectType).first!
     let newObject = ObjectType()

     realm.beginWrite()
     realm.add(newObject)
     realm.delete(oldObject)
     realm.cancelWrite()
     ```

     Both `oldObject` and `newObject` will return `true` for `isInvalidated`, but re-running the query which provided
     `oldObject` will once again return the valid object.

     - warning: This method may only be called during a write transaction.
     */
    public func cancelWrite() {
        realm.cancelWrite()
    }

    /**
     Indicates whether the Realm is currently in a write transaction.

     - warning:  Do not simply check this property and then start a write transaction whenever an object needs to be
     created, updated, or removed. Doing so might cause a large number of write transactions to be created,
     degrading performance. Instead, always prefer performing multiple updates during a single transaction.
     */
    public var isInWriteTransaction: Bool {
        return realm.isInWriteTransaction
    }

    // MARK: Adding and Creating objects

    /**
     Adds or updates an existing object into the Realm.

     Only pass `true` to `update` if the object has a primary key. If no objects exist in the Realm with the same
     primary key value, the object is inserted. Otherwise, the existing object is updated with any changed values.

     When added, all child relationships referenced by this object will also be added to the Realm if they are not
     already in it. If the object or any related objects are already being managed by a different Realm an error will be
     thrown. Instead, use one of the `create` functions to insert a copy of a managed object into a different Realm.

     The object to be added must be valid and cannot have been previously deleted from a Realm (i.e. `isInvalidated`
     must be `false`).

     - parameter object: The object to be added to this Realm.
     - parameter update: If `true`, the Realm will try to find an existing copy of the object (with the same primary
     key), and update it. Otherwise, the object will be added.
     */
    public func add<T: Object>(_ object: T) {
        let update = T.primaryKey() != nil
        realm.add(object, update: update)
    }

    /**
     Adds or updates all the objects in a collection into the Realm.

     - see: `add(_:update:)`

     - warning: This method may only be called during a write transaction.

     - parameter objects: A sequence which contains objects to be added to the Realm.
     - parameter update: If `true`, objects that are already in the Realm will be updated instead of added anew.
     */
    public func add<S: Sequence>(_ objects: S) where S.Iterator.Element: Object {
        typealias Element = S.Iterator.Element
        let update = Element.primaryKey() != nil
        for obj in objects {
            realm.add(obj, update: update)
        }
    }

    /**
     Creates or updates a Realm object with a given value, adding it to the Realm and returning it.

     Only pass `true` to `update` if the object has a primary key. If no objects exist in
     the Realm with the same primary key value, the object is inserted. Otherwise,
     the existing object is updated with any changed values.

     The `value` argument can be a key-value coding compliant object, an array or dictionary returned from the methods
     in `NSJSONSerialization`, or an `Array` containing one element for each managed property. An exception will be
     thrown if any required properties are not present and those properties were not defined with default values. Do not
     pass in a `LinkingObjects` instance, either by itself or as a member of a collection.

     When passing in an `Array` as the `value` argument, all properties must be present, valid and in the same order as
     the properties defined in the model.

     - warning: This method may only be called during a write transaction.

     - parameter type:   The type of the object to create.
     - parameter value:  The value used to populate the object.
     - parameter update: If `true`, the Realm will try to find an existing copy of the object (with the same primary
     key), and update it. Otherwise, the object will be added.

     - returns: The newly created object.
     */
    @discardableResult
    public func create<T: Object>(_ type: T.Type, value: Any = [:]) -> T {
        let typeName = (type as Object.Type).className()
        let update = schema[typeName]?.primaryKeyProperty != nil
        return realm.create(type, value: value, update: update)
    }

    /**
     This method is useful only in specialized circumstances, for example, when building
     components that integrate with Realm. If you are simply building an app on Realm, it is
     recommended to use the typed method `create(_:value:update:)`.

     Creates or updates an object with the given class name and adds it to the `Realm`, populating
     the object with the given value.

     When 'update' is 'true', the object must have a primary key. If no objects exist in
     the Realm instance with the same primary key value, the object is inserted. Otherwise,
     the existing object is updated with any changed values.

     The `value` argument is used to populate the object. It can be a key-value coding compliant object, an array or
     dictionary returned from the methods in `NSJSONSerialization`, or an `Array` containing one element for each
     managed property. An exception will be thrown if any required properties are not present and those properties were
     not defined with default values.

     When passing in an `Array` as the `value` argument, all properties must be present, valid and in the same order as
     the properties defined in the model.

     - warning: This method can only be called during a write transaction.

     - parameter className:  The class name of the object to create.
     - parameter value:      The value used to populate the object.
     - parameter update:     If true will try to update existing objects with the same primary key.

     - returns: The created object.

     :nodoc:
     */
    @discardableResult
    public func dynamicCreate(_ typeName: String, value: Any = [:]) -> DynamicObject! {
        let update = schema[typeName]?.primaryKeyProperty != nil
        return realm.dynamicCreate(typeName, value: value, update: update)
    }

    // MARK: Deleting objects

    /**
     Deletes an object from the Realm. Once the object is deleted it is considered invalidated.

     - warning: This method may only be called during a write transaction.

     - parameter object: The object to be deleted.
     */
    public func delete<T: Object>(_ object: T) {
        realm.delete(object)
        deletedTypes.append(T.self)
    }

    /**
     Deletes zero or more objects from the Realm.

     - warning: This method may only be called during a write transaction.

     - parameter objects:   The objects to be deleted. This can be a `List<Object>`, `Results<Object>`, or any other
     Swift `Sequence` whose elements are `Object`s.
     */
    public func delete<S: Sequence>(_ objects: S) where S.Iterator.Element: Object {
        realm.delete(objects)
        let type = S.Iterator.Element.self
        deletedTypes.append(type)
    }

    /**
     Deletes zero or more objects from the Realm.

     - warning: This method may only be called during a write transaction.

     - parameter objects: A list of objects to delete.

     :nodoc:
     */
    public func delete<T: Object>(_ objects: List<T>) {
        realm.delete(objects)
        deletedTypes.append(T.self)
    }

    /**
     Deletes zero or more objects from the Realm.

     - warning: This method may only be called during a write transaction.

     - parameter objects: A `Results` containing the objects to be deleted.

     :nodoc:
     */
    public func delete<T: Object>(_ objects: Results<T>) {
        realm.delete(objects)
        deletedTypes.append(T.self)
    }

    /**
     Returns all objects of the given type stored in the Realm.

     - parameter type: The type of the objects to be returned.

     - returns: A `Results` containing the objects.
     */
    public func deleteAll() {
        realm.deleteAll()
    }

    // MARK: Object Retrieval

    /**
     Returns all objects of the given type stored in the Realm.

     - parameter type: The type of the objects to be returned.

     - returns: A `Results` containing the objects.
     */
    public func objects<T: Object>(_ type: T.Type) -> Results<T> {
        return realm.objects(type)
    }

    /**
     This method is useful only in specialized circumstances, for example, when building
     components that integrate with Realm. If you are simply building an app on Realm, it is
     recommended to use the typed method `objects(type:)`.

     Returns all objects for a given class name in the Realm.

     - parameter typeName: The class name of the objects to be returned.
     - returns: All objects for the given class name as dynamic objects

     :nodoc:
     */
    public func dynamicObjects(_ typeName: String) -> Results<DynamicObject> {
        return realm.dynamicObjects(typeName)
    }

    /**
     Retrieves the single instance of a given object type with the given primary key from the Realm.

     This method requires that `primaryKey()` be overridden on the given object class.

     - see: `Object.primaryKey()`

     - parameter type: The type of the object to be returned.
     - parameter key:  The primary key of the desired object.

     - returns: An object of type `type`, or `nil` if no instance with the given primary key exists.
     */
    public func object<T: RealmSwift.Object, K>(ofType type: T.Type, forPrimaryKey key: K) -> T? {
        return realm.object(ofType: type, forPrimaryKey: key)
    }

    /**
     This method is useful only in specialized circumstances, for example, when building
     components that integrate with Realm. If you are simply building an app on Realm, it is
     recommended to use the typed method `objectForPrimaryKey(_:key:)`.

     Get a dynamic object with the given class name and primary key.

     Returns `nil` if no object exists with the given class name and primary key.

     This method requires that `primaryKey()` be overridden on the given subclass.

     - see: Object.primaryKey()

     - warning: This method is useful only in specialized circumstances.

     - parameter className:  The class name of the object to be returned.
     - parameter key:        The primary key of the desired object.

     - returns: An object of type `DynamicObject` or `nil` if an object with the given primary key does not exist.

     :nodoc:
     */
    public func dynamicObject(ofType typeName: String, forPrimaryKey key: Any) -> RealmSwift.DynamicObject? {
        return realm.dynamicObject(ofType: typeName, forPrimaryKey: key)
    }

    // MARK: Notifications

    /**
     Adds a notification handler for changes made to this Realm, and returns a notification token.

     Notification handlers are called after each write transaction is committed, independent of the thread or process.

     Handler blocks are called on the same thread that they were added on, and may only be added on threads which are
     currently within a run loop. Unless you are specifically creating and running a run loop on a background thread,
     this will normally only be the main thread.

     Notifications can't be delivered as long as the run loop is blocked by other activity. When notifications can't be
     delivered instantly, multiple notifications may be coalesced.

     You must retain the returned token for as long as you want updates to be sent to the block. To stop receiving
     updates, call `invalidate()` on the token.

     - parameter block: A block which is called to process Realm notifications. It receives the following parameters:
     `notification`: the incoming notification; `realm`: the Realm for which the notification
     occurred.

     - returns: A token which must be held for as long as you wish to continue receiving change notifications.
     */
    public func observe(_ block: @escaping NotificationBlock) -> NotificationToken {
        return realm.observe({ notif, _ in
            block(notif, self)
        })
    }

    // MARK: Autorefresh and Refresh

    /**
     Set this property to `true` to automatically update this Realm when changes happen in other threads.

     If set to `true` (the default), changes made on other threads will be reflected in this Realm on the next cycle of
     the run loop after the changes are committed.  If set to `false`, you must manually call `refresh()` on the Realm
     to update it to get the latest data.

     Note that by default, background threads do not have an active run loop and you will need to manually call
     `refresh()` in order to update to the latest version, even if `autorefresh` is set to `true`.

     Even with this property enabled, you can still call `refresh()` at any time to update the Realm before the
     automatic refresh would occur.

     Notifications are sent when a write transaction is committed whether or not automatic refreshing is enabled.

     Disabling `autorefresh` on a `Realm` without any strong references to it will not have any effect, and
     `autorefresh` will revert back to `true` the next time the Realm is created. This is normally irrelevant as it
     means that there is nothing to refresh (as managed `Object`s, `List`s, and `Results` have strong references to the
     `Realm` that manages them), but it means that setting `autorefresh = false` in
     `application(_:didFinishLaunchingWithOptions:)` and only later storing Realm objects will not work.

     Defaults to `true`.
     */
    public var autorefresh: Bool {
        get {
            return realm.autorefresh
        }
        set {
            realm.autorefresh = newValue
        }
    }

    /**
     Updates the Realm and outstanding objects managed by the Realm to point to the most recent data.

     - returns: Whether there were any updates for the Realm. Note that `true` may be returned even if no data actually
     changed.
     */
    @discardableResult
    public func refresh() -> Bool {
        return realm.refresh()
    }

    // MARK: Invalidation

    /**
     Invalidates all `Object`s, `Results`, `LinkingObjects`, and `List`s managed by the Realm.

     A Realm holds a read lock on the version of the data accessed by it, so
     that changes made to the Realm on different threads do not modify or delete the
     data seen by this Realm. Calling this method releases the read lock,
     allowing the space used on disk to be reused by later write transactions rather
     than growing the file. This method should be called before performing long
     blocking operations on a background thread on which you previously read data
     from the Realm which you no longer need.

     All `Object`, `Results` and `List` instances obtained from this `Realm` instance on the current thread are
     invalidated. `Object`s and `Array`s cannot be used. `Results` will become empty. The Realm itself remains valid,
     and a new read transaction is implicitly begun the next time data is read from the Realm.

     Calling this method multiple times in a row without reading any data from the
     Realm, or before ever reading any data from the Realm, is a no-op. This method
     may not be called on a read-only Realm.
     */
    public func invalidate() {
        realm.invalidate()
    }

    // MARK: Writing a Copy

    /**
     Writes a compacted and optionally encrypted copy of the Realm to the given local URL.

     The destination file cannot already exist.

     Note that if this method is called from within a write transaction, the *current* data is written, not the data
     from the point when the previous write transaction was committed.

     - parameter fileURL:       Local URL to save the Realm to.
     - parameter encryptionKey: Optional 64-byte encryption key to encrypt the new file with.

     - throws: An `NSError` if the copy could not be written.
     */
    public func writeCopy(toFile fileURL: URL, encryptionKey: Data? = nil) {
        do {
            try realm.writeCopy(toFile: fileURL, encryptionKey: encryptionKey)
        } catch {
            RealmS.handleError?(self, error as NSError, .encrypt)
        }
    }

    // MARK: Internal
    internal var realm: Realm

    internal init(_ realm: Realm) {
        self.realm = realm
    }
}

// MARK: Equatable

extension RealmS: Equatable { }

/// Returns whether the two realms are equal.
public func == (lhs: RealmS, rhs: RealmS) -> Bool { // swiftlint:disable:this valid_docs
    return lhs.realm == rhs.realm
}

// MARK: Notifications

/// Closure to run when the data in a Realm was modified.
public typealias NotificationBlock = (_ notification: Realm.Notification, _ realm: RealmS) -> Void

// MARK: Unavailable

extension RealmS {

    @available( *, unavailable, renamed: "isInWriteTransaction")
    public var inWriteTransaction: Bool { fatalError() }

    @available( *, unavailable, renamed: "object(ofType:forPrimaryKey:)")
    public func objectForPrimaryKey<T: Object>(_ type: T.Type, key: Any) -> T? { fatalError() }

    @available( *, unavailable, renamed: "dynamicObject(ofType:forPrimaryKey:)")
    public func dynamicObjectForPrimaryKey(_ className: String, key: Any) -> DynamicObject? { fatalError() }

    @available( *, unavailable, renamed: "writeCopy(toFile:encryptionKey:)")
    public func writeCopyToURL(_ fileURL: NSURL, encryptionKey: Data? = nil) throws { fatalError() }
}
