//
//  LoginViewController.swift
//  JUXER
//
//  Created by Joao Victor Almeida on 02/02/16.
//  Copyright © 2016 Joao Victor Almeida. All rights reserved.
//

import UIKit
import FBSDKCoreKit
import FBSDKLoginKit
import SCLAlertView

class LoginViewController: UIViewController, UIPageViewControllerDataSource  {

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var welcomeText2: UILabel!
    @IBOutlet weak var loginButton: UIButton!
    @IBAction func loginButtonPressed(sender: AnyObject) {
        
        dispatch_async(dispatch_get_main_queue()){
            self.startLoadOverlay()
        }
        
        let fbLoginManager : FBSDKLoginManager = FBSDKLoginManager()
        
        fbLoginManager.logInWithReadPermissions(["public_profile", "email", "user_friends"], fromViewController: self) { (result, error) in

            if error != nil
            {
                print(error.localizedDescription)
                dispatch_async(dispatch_get_main_queue()){
                    self.stopLoadOverlay()
                    SCLAlertView().showError("Erro", subTitle: "Não foi possivel fazer login, tente novamente!", closeButtonTitle: "OK", colorStyle: 0xFF005A, colorTextButton: 0xFFFFFF)
                }
            }
            else if result.isCancelled
            {
                dispatch_async(dispatch_get_main_queue()){
                    self.stopLoadOverlay()
                }
                print(result.debugDescription)
            }
            else
            {
                self.saveAndSubmitFBUser()
            }
        }
    }

    var overlay: UIView!
    var pageViewController: UIPageViewController!
    var pageLabels: NSArray!
    var pageImages: NSArray!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Gradient Background
        let view: UIView = UIView(frame: CGRectMake(0, 0, self.view.frame.width, self.view.frame.height))
        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.frame = view.bounds
        gradient.colors = [UIColor.init(red: 191/255, green: 0/255, blue: 96/255, alpha: 1).CGColor, UIColor.init(red: 93/255, green: 0/255, blue: 94/255, alpha: 1).CGColor]
        view.layer.insertSublayer(gradient, atIndex: 0)
        self.view.layer.insertSublayer(view.layer, atIndex: 0)
        
        //Assing Page Objects
        self.pageLabels = NSArray(objects: "Deixe seu evento mais animado!", "Escaneie o código do evento.", "Escolha uma música entre as disponíveis nas playlists.", "Aproveite as músicas escolhidas por outras pessoas enquanto a sua está na fila!")
        self.pageImages = NSArray(objects: "JukeboxIcon", "BarcodeIcon", "IdeiaIcon", "DancingIcon")
        
        //Configure PageViewController
        self.pageViewController = self.storyboard?.instantiateViewControllerWithIdentifier("PageViewController") as! UIPageViewController
        self.pageViewController.dataSource = self
        
        let startVC = self.viewControllerAtIndex(0) as ContentViewController
        let viewControllers = NSArray(object: startVC)
        
        self.pageViewController.setViewControllers(viewControllers as? [UIViewController], direction: .Forward, animated: true, completion: nil)
        
        self.pageViewController.view.frame = CGRectMake(0, 0, self.view.frame.width, self.view.frame.height)
        
        //Add PageViewController
        self.addChildViewController(self.pageViewController)
        self.view.addSubview(self.pageViewController.view)
        self.pageViewController.didMoveToParentViewController(self)
        
        //Bring Login Button to front
        self.view.bringSubviewToFront(loginButton)
        
    }
    
    private func saveAndSubmitFBUser(){
        
        if((FBSDKAccessToken.currentAccessToken()) != nil)
        {
            
            FBSDKGraphRequest(graphPath: "me", parameters: ["fields": "email, name, first_name, last_name, id"]).startWithCompletionHandler({ (connection, result, error) -> Void in
                
                if error == nil && result != nil
                {
                    let userName: NSString = result.valueForKey("name") as! NSString
                    let userEmail:  NSString = result.valueForKey("email") as! NSString
                    let userFirstName: NSString = result.valueForKey("first_name") as! NSString
                    let userLastName: NSString = result.valueForKey("last_name") as! NSString
                    let userId: NSString = result.valueForKey("id") as! NSString
                    let userPictureUrl: String = "https://graph.facebook.com/\(userId)/picture?type=large"
                    
                    let user = User()
                    user.name = "\(userName)"
                    user.pictureUrl = "\(userPictureUrl)"
                    user.id = "\(userId)"
                    user.lastName = "\(userLastName)"
                    user.firstName = "\(userFirstName)"
                    user.email = "\(userEmail)"
                    user.anonymous = 0
                    
                    let jsonObject: [String : AnyObject] =
                        [ "email": "\(userEmail)",
                            "first_name": "\(userFirstName)",
                            "last_name": "\(userLastName)",
                            "username": "\(userEmail)",
                            "picture": "\(userPictureUrl)",
                            "fb_id": "\(userId)" ]
                    
                    if NSJSONSerialization.isValidJSONObject(jsonObject) {
                        
                        do {
                            
                            let JSON = try NSJSONSerialization.dataWithJSONObject(jsonObject, options: [])
                            
                            // create post request
                            let request = NSMutableURLRequest(URL: NSURL(string: "http://juxer.club/api/user/login/")!)
                            request.HTTPMethod = "POST"
                            
                            // insert json data to the request
                            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                            request.HTTPBody = JSON
                            
                            let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
                                let httpResponse = response as! NSHTTPURLResponse
                                if error != nil{
                                    print(error)
                                    self.logOut()
                                    dispatch_async(dispatch_get_main_queue()){
                                        self.stopLoadOverlay()
                                        self.showConectionErrorAlert()
                                    }
                                } else if httpResponse.statusCode == 200 {
                                    UserDAO.insert(user)
                                    var resultData = NSString(data: data!, encoding: NSUTF8StringEncoding)!
                                    resultData = resultData.stringByReplacingOccurrencesOfString("\"", withString: "")
                                    self.storeSessionToken(String(resultData))
                                    self.getFBProfilePictureAndSegue(userPictureUrl)
                                    
                                } else {
                                    self.logOut()
                                    dispatch_async(dispatch_get_main_queue()){
                                        self.stopLoadOverlay()
                                        self.showErrorAlert()
                                    }
                                }
                            }
                            task.resume()
                        } catch {
                            print(error)
                            self.logOut()
                            dispatch_async(dispatch_get_main_queue()){
                                self.stopLoadOverlay()
                                self.showErrorAlert()
                            }
                        }
                    }
                } else {
                    print(error)
                    self.logOut()
                    dispatch_async(dispatch_get_main_queue()){
                        self.stopLoadOverlay()
                        self.showErrorAlert()
                    }
                }
                
            })
            
        }
    }
    
    func getFBProfilePictureAndSegue(url: String){
        let url = NSURL(string: url)
        let request = NSURLRequest(URL: url!)
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
            if error != nil {
                print(error)
                self.deleteUser()
                self.logOut()
                dispatch_async(dispatch_get_main_queue()){
                    self.stopLoadOverlay()
                    self.showConectionErrorAlert()
                }
            } else {
                let httpResponse = response as! NSHTTPURLResponse
                if httpResponse.statusCode == 200 {
                    let documentsDirectory:String?
                    var path:[AnyObject] = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
                    print(8)
                    if path.count > 0 {
                        documentsDirectory = path[0] as? String
                        let savePath = documentsDirectory! + "/profilePic.jpg"
                        NSFileManager.defaultManager().createFileAtPath(savePath, contents: data, attributes: nil)
                        dispatch_async(dispatch_get_main_queue()){
                            self.performSegueWithIdentifier("toHome", sender: self)
                        }
                    }
                } else {
                    self.deleteUser()
                    self.logOut()
                    dispatch_async(dispatch_get_main_queue()){
                        self.stopLoadOverlay()
                        self.showErrorAlert()
                    }
                }
            }
        })
        task.resume()
    }
    
    func showErrorAlert(){
        SCLAlertView().showError("Erro", subTitle: "Não foi possivel fazer login, tente novamente!", closeButtonTitle: "OK", colorStyle: 0xFF005A, colorTextButton: 0xFFFFFF)
    }
    
    func showConectionErrorAlert(){
        SCLAlertView().showError("Erro de Conexão", subTitle: "Não foi possivel conectar ao servidor, tente novamente!", closeButtonTitle: "OK", colorStyle: 0xFF005A, colorTextButton: 0xFFFFFF)
    }
    
    private func storeSessionToken(userToken: String){
        let session = Session()
        session.token = userToken
        SessionDAO.insert(session)
    }
    
    func startLoadOverlay(){
        overlay = UIView(frame: CGRectMake(0, 0, self.view.bounds.width, self.view.bounds.height))
        overlay.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        self.activityIndicator.startAnimating()
        self.view.addSubview(self.overlay)
        self.view.bringSubviewToFront(self.activityIndicator)
        self.loginButton.userInteractionEnabled = false
    }
    
    func stopLoadOverlay(){
        self.activityIndicator.stopAnimating()
        self.overlay.removeFromSuperview()
        self.loginButton.userInteractionEnabled = true
    }
    
    private func deleteUser(){
        if let user:[User] = UserDAO.fetchUser() {
            UserDAO.delete(user[0])
        }
    }
    
    private func logOut(){
        let loginManager = FBSDKLoginManager()
        loginManager.logOut()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Page View Methods
    
    func viewControllerAtIndex(index: Int) -> ContentViewController {
        
        if (self.pageLabels.count == 0) || (index >= self.pageLabels.count) {
            return ContentViewController()
        }
        let viewController: ContentViewController = self.storyboard?.instantiateViewControllerWithIdentifier("ContentViewController") as! ContentViewController
 
        viewController.pageLabel = self.pageLabels[index] as! String
        viewController.pageIndex = index
        viewController.pageIcon = self.pageImages[index] as! String
        
        return viewController
        
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        
        let viewController = viewController as! ContentViewController
        var index = viewController.pageIndex as Int
        
        if index == NSNotFound {
            return nil
        }
        
        index += 1
        
        if index == self.pageLabels.count {
            return nil
        }
        
        return self.viewControllerAtIndex(index)
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        
        let viewController = viewController as! ContentViewController
        var index = viewController.pageIndex as Int
        
        if index == 0 || index == NSNotFound {
            return nil
        }
        
        index -= 1
        return self.viewControllerAtIndex(index)
    }
    
    func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 4
    }
    
    func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 0
    }
    
    
}
