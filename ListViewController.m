//
//  ListViewController.m
//  Angler Ally
//
//  Created by Scott Gardner on 8/22/12.
//  Copyright (c) 2012 Scott Gardner. All rights reserved.
//

#import "ListViewController.h"

@interface ListViewController () <NSFetchedResultsControllerDelegate, UISearchBarDelegate, UISearchDisplayDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) LocalizationsController *localized;
@property (weak, nonatomic) IBOutlet SegmentedControl *filterSegmentedControl;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) NSFetchRequest *searchFetchRequest;
@property (nonatomic, copy) NSArray *searchResults;
@property (nonatomic, strong) UIActionSheet *actionMenu;
@property (nonatomic, strong) UITableViewCell *cellForSelectedItem;
@end

@implementation ListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.localized = [LocalizationsController new];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    /* Explanation: We are segued to this prototype-cell-based table view controller dynamically from one of several
     static table view cells in the preceding table view controller (an add/edit detail view). We are fed the Core Data
     entity as a string, and optionally fed a value string for the previously selected item. The value string will be
     nil if the user is adding a new record in the segueing table view controller, or if they have cleared the selection
     in this table view controller at any point during initial creation or editing of the parent object. The value string
     is the "name" attribute value, which is an attribute of all entities utilizing this table view controller. If we
     received a value string, we first determine which entity to load and if that entity has any favorite items 
     (favorites are designated in Settings). Then we find the object for the value string. Then we set the segmented 
     control to either display all items if there are no favorites (including the object for the value string), or else
     display the filtered favorite items only (inclusive of the object for the value string). Finally, we scroll to the 
     selected value.
    */
  
    NSFetchRequest *fetchRequest = [NSFetchRequest new];
    [fetchRequest setEntity:[NSEntityDescription entityForName:self.entityForList inManagedObjectContext:self.managedObjectContext]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"favorite == %@", @YES]];
    NSError *error;
    NSUInteger countOfFavorites = [self.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    __block id item;
    __block BOOL itemIsFavorite = NO;
    
    if ([self.selectedItem length]) {
        [self performFetchAndReloadData:NO];
        
        [self.fetchedResultsController.fetchedObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([[obj name] isEqualToString:self.selectedItem]) {
                item = obj;
                itemIsFavorite = [[obj valueForKey:@"favorite"] boolValue];
                *stop = YES;
            }
        }];
    }
    
    if ((!item && countOfFavorites) || itemIsFavorite) {
        self.filterSegmentedControl.selectedSegmentIndex = 1;
    }
    
    [self filterSegmentedControlIndexChanged:nil];
    
    if (item) {
        [self.tableView scrollToRowAtIndexPath:[self.fetchedResultsController indexPathForObject:item] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.actionMenu.visible) {
        [self.actionMenu dismissWithClickedButtonIndex:self.actionMenu.cancelButtonIndex animated:YES];
    }
}

#pragma mark - Custom accessors

- (NSFetchRequest *)searchFetchRequest
{
    if (!_searchFetchRequest) {
        _searchFetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entityForList];
        NSSortDescriptor *nameSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)];
        _searchFetchRequest.sortDescriptors = @[nameSortDescriptor];
    }
    
    return _searchFetchRequest;
}

- (UIActionSheet *)actionMenu
{
    if (!_actionMenu) {
        _actionMenu = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:self.localized.cancel destructiveButtonTitle:self.localized.clearSelection otherButtonTitles:nil];
    }
    
    return _actionMenu;
}

#pragma mark - Private methods

- (IBAction)filterSegmentedControlIndexChanged:(id)sender
{
    switch (self.filterSegmentedControl.selectedSegmentIndex) {
        case 0: // All
        {
            [self.fetchedResultsController.fetchRequest setPredicate:nil];
            [self performFetchAndReloadData:YES];
        }
            break;
            
        case 1: // Favorites
        {
            [self.fetchedResultsController.fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"favorite == %@", @YES]];
            [self performFetchAndReloadData:YES];
        }
            break;
            
        default:
            break;
    }
}

- (void)searchForText:(NSString *)searchText
{
    NSPredicate *predicate;
    
    if (self.filterSegmentedControl.selectedSegmentIndex == 0) { // All
        predicate = [NSPredicate predicateWithFormat:@"name contains[cd] %@", searchText];
    } else { // Favorites
        predicate = [NSPredicate predicateWithFormat:@"name contains[cd] %@ and favorite == 1", searchText];
    }
    
    [self.searchFetchRequest setPredicate:predicate];
    NSError *error;
    self.searchResults = [self.managedObjectContext executeFetchRequest:self.searchFetchRequest error:&error];
}

- (IBAction)presentActionMenu:(id)sender
{
    if (!self.actionMenu.visible) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            [self.actionMenu showInView:self.view];
        } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.actionMenu showFromBarButtonItem:sender animated:YES];
        }
    } else {
        [self.actionMenu dismissWithClickedButtonIndex:self.actionMenu.cancelButtonIndex animated:YES];
    }
}

#pragma mark - UITableViewDataSource and related

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([tableView isEqual:self.tableView]) {
        return [[self.fetchedResultsController sections] count];
    } else { // Search results
        return 1;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([tableView isEqual:self.tableView]) {
        return [[self.fetchedResultsController sections][section] numberOfObjects];
    } else { // Search results
        return [self.searchResults count];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if ([tableView isEqual:self.tableView]) {
        return self.fetchedResultsController.sectionIndexTitles[section];
    } else { // Search results
        return nil;
    }
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if ([tableView isEqual:self.tableView]) {
        // Add magnifying glass icon at top of index
        NSMutableArray *index = [NSMutableArray arrayWithObject:UITableViewIndexSearch];
        
        [index addObjectsFromArray:self.fetchedResultsController.sectionIndexTitles];
        return index;
    } else { // Search results
        return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    if ([tableView isEqual:self.tableView]) {
        // Adjust for offset created by adding magnifying glass icon at top of index
        if (index > 0) {
            return [self.fetchedResultsController sectionForSectionIndexTitle:title atIndex:index - 1];
        } else { // Magnifying glass was tapped
            self.tableView.contentOffset = CGPointZero;
            return NSNotFound;
        }
    } else { // Search results
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Need to specify dequeuing on self.tableView because the search results tableView does not know about the prototype cell
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"ListItemCell"];
    [self tableView:tableView configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)tableView:(UITableView *)tableView configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    id item;
    
    if ([tableView isEqual:self.tableView]) {
        if ([self.fetchedResultsController.fetchedObjects count]) {
            item = [self.fetchedResultsController objectAtIndexPath:indexPath];
        }
    } else { // Search results
        item = [self.searchResults objectAtIndex:indexPath.row];
    }
    
    cell.textLabel.text = [item name];
    BOOL favorite = [[item valueForKey:@"favorite"] boolValue];
    
    if (favorite) {
        cell.imageView.image = [UIImage imageNamed:@"gray-star"];
    } else {
        cell.imageView.image = nil;
    }
    
    if ([[item name] isEqualToString:self.selectedItem]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        self.cellForSelectedItem = cell;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    if (![cell.textLabel.text isEqualToString:self.selectedItem]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        
        // To remove the checkmark from the previously selected item
        self.cellForSelectedItem.accessoryType = UITableViewCellAccessoryNone;
        self.selectedItem = cell.textLabel.text;
    }
    
    [self.delegate listViewControllerDidFinish:self];
}

#pragma mark - NSFetchedResultsController, NSFetchedResultsControllerDelegate, and related

- (NSFetchedResultsController *)fetchedResultsController
{
    if (!_fetchedResultsController) {
        NSFetchRequest *fetchRequest = [NSFetchRequest new];
        [fetchRequest setEntity:[NSEntityDescription entityForName:self.entityForList inManagedObjectContext:self.managedObjectContext]];
        NSSortDescriptor *sectionKeySortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"sectionKey" ascending:YES selector:@selector(localizedStandardCompare:)];
        NSSortDescriptor *nameSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)];
        [fetchRequest setSortDescriptors:@[sectionKeySortDescriptor, nameSortDescriptor]];
        [fetchRequest setFetchBatchSize:20];
        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:@"sectionKey" cacheName:nil];
        _fetchedResultsController.delegate = self;
    }
    
    return _fetchedResultsController;
}

- (void)performFetchAndReloadData:(BOOL)reload
{
    NSError *error;
    
    if (![self.fetchedResultsController performFetch:&error]) {
        FATAL_ERROR(error);
    }
    
    if (reload) {
        [self.tableView reloadData];
    }
}

#pragma mark - UISearchBarDelegate

#pragma mark - UISearchDisplayDelegate

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self searchForText:searchString];
    return YES;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0: // Clear selection
            
            // self.cellForSelectedItem will only be set if selectedItem is displayed
            if (self.cellForSelectedItem) {
                self.cellForSelectedItem.accessoryType = UITableViewCellAccessoryNone;
            }
            
            self.selectedItem = nil;
            [self.delegate listViewControllerDidFinish:self];
            break;
            
        default:
            break;
    }
}

@end
