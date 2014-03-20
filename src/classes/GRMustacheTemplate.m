// The MIT License
// 
// Copyright (c) 2014 Gwendal Roué
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "GRMustacheTemplate_private.h"
#import "GRMustacheContext_private.h"
#import "GRMustacheTemplateRepository_private.h"
#import "GRMustacheRendering_private.h"
//#import "GRMustacheTemplateComponent_private.h"
#import "GRMustachePartial_private.h"
#import "GRMustacheAST_private.h"
#import "GRMustacheRenderingASTVisitor_private.h"

@interface GRMustacheTemplate()<GRMustacheRendering>
@end

@implementation GRMustacheTemplate
@synthesize templateRepository=_templateRepository;
@synthesize partial=_partial;
@synthesize baseContext=_baseContext;

+ (instancetype)templateFromString:(NSString *)templateString error:(NSError **)error
{
    GRMustacheTemplateRepository *templateRepository = [GRMustacheRendering currentTemplateRepository];
    if (templateRepository == nil) {
        templateRepository = [GRMustacheTemplateRepository templateRepositoryWithBundle:[NSBundle mainBundle]];
    }
    GRMustacheContentType contentType = [GRMustacheRendering currentContentType];
    return [templateRepository templateFromString:templateString contentType:contentType error:error];
}

+ (instancetype)templateFromResource:(NSString *)name bundle:(NSBundle *)bundle error:(NSError **)error
{
    GRMustacheTemplateRepository *templateRepository = [GRMustacheTemplateRepository templateRepositoryWithBundle:bundle];
    return [templateRepository templateNamed:name error:error];
}

+ (instancetype)templateFromContentsOfFile:(NSString *)path error:(NSError **)error
{
    NSString *directoryPath = [path stringByDeletingLastPathComponent];
    NSString *templateExtension = [path pathExtension];
    NSString *templateName = [[path lastPathComponent] stringByDeletingPathExtension];
    GRMustacheTemplateRepository *templateRepository = [GRMustacheTemplateRepository templateRepositoryWithDirectory:directoryPath templateExtension:templateExtension encoding:NSUTF8StringEncoding];
    return [templateRepository templateNamed:templateName error:error];
}

+ (instancetype)templateFromContentsOfURL:(NSURL *)URL error:(NSError **)error
{
    NSURL *baseURL = [URL URLByDeletingLastPathComponent];
    NSString *templateExtension = [URL pathExtension];
    NSString *templateName = [[URL lastPathComponent] stringByDeletingPathExtension];
    GRMustacheTemplateRepository *templateRepository = [GRMustacheTemplateRepository templateRepositoryWithBaseURL:baseURL templateExtension:templateExtension encoding:NSUTF8StringEncoding];
    return [templateRepository templateNamed:templateName error:error];
}

+ (NSString *)renderObject:(id)object fromString:(NSString *)templateString error:(NSError **)error
{
    GRMustacheTemplate *template = [GRMustacheTemplate templateFromString:templateString error:error];
    return [template renderObject:object error:error];
}

+ (NSString *)renderObject:(id)object fromResource:(NSString *)name bundle:(NSBundle *)bundle error:(NSError **)error
{
    GRMustacheTemplate *template = [GRMustacheTemplate templateFromResource:name bundle:bundle error:error];
    return [template renderObject:object error:error];
}

- (void)dealloc
{
    [_partial release];
    [_baseContext release];
    [super dealloc];
}

- (void)extendBaseContextWithObject:(id)object
{
    self.baseContext = [self.baseContext contextByAddingObject:object];
}

- (void)extendBaseContextWithProtectedObject:(id)object
{
    self.baseContext = [self.baseContext contextByAddingProtectedObject:object];
}

- (void)extendBaseContextWithTagDelegate:(id<GRMustacheTagDelegate>)tagDelegate
{
    self.baseContext = [self.baseContext contextByAddingTagDelegate:tagDelegate];
}

- (NSString *)renderObject:(id)object error:(NSError **)error
{
    GRMustacheContext *context = [self.baseContext contextByAddingObject:object];
    return [self renderContentWithContext:context HTMLSafe:NULL error:error];
}

- (NSString *)renderObjectsFromArray:(NSArray *)objects error:(NSError **)error
{
    GRMustacheContext *context = self.baseContext;
    for (id object in objects) {
        context = [context contextByAddingObject:object];
    }
    return [self renderContentWithContext:context HTMLSafe:NULL error:error];
}

- (NSString *)renderContentWithContext:(GRMustacheContext *)context HTMLSafe:(BOOL *)HTMLSafe error:(NSError **)error
{
    GRMustacheRenderingASTVisitor *visitor = [[[GRMustacheRenderingASTVisitor alloc] initWithContentType:_partial.AST.contentType context:context] autorelease];

    [GRMustacheRendering pushCurrentTemplateRepository:self.templateRepository];
    BOOL success = [_partial accept:visitor error:error];
    [GRMustacheRendering popCurrentTemplateRepository];

    if (!success) {
        return nil;
    }
    
    return [visitor renderingWithHTMLSafe:HTMLSafe error:error];
}

- (void)setBaseContext:(GRMustacheContext *)baseContext
{
    if (!baseContext) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid baseContext:nil"];
        return;
    }
    
    if (_baseContext != baseContext) {
        [_baseContext release];
        _baseContext = [baseContext retain];
    }
}


#pragma mark - <GRMustacheRendering>

// Allows template to render as "dynamic partials"
- (NSString *)renderForMustacheTag:(GRMustacheTag *)tag context:(GRMustacheContext *)context HTMLSafe:(BOOL *)HTMLSafe error:(NSError **)error
{
    return [self renderContentWithContext:context HTMLSafe:HTMLSafe error:error];
}

@end
