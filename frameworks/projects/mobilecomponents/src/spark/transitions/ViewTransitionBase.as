////////////////////////////////////////////////////////////////////////////////
//
//  ADOBE SYSTEMS INCORPORATED
//  Copyright 2010 Adobe Systems Incorporated
//  All Rights Reserved.
//
//  NOTICE: Adobe permits you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////

package spark.transitions
{
    
import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.events.EventDispatcher;
import flash.geom.Rectangle;

import mx.core.IVisualElement;
import mx.core.IVisualElementContainer;
import mx.core.UIComponent;
import mx.core.mx_internal;
import mx.effects.Effect;
import mx.effects.IEffect;
import mx.effects.Parallel;
import mx.effects.Pause;
import mx.events.EffectEvent;
import mx.events.FlexEvent;

import spark.components.ActionBar;
import spark.components.Group;
import spark.components.Image;
import spark.components.TabbedViewNavigator;
import spark.components.View;
import spark.components.ViewNavigator;
import spark.components.supportClasses.ButtonBarBase;
import spark.components.supportClasses.ViewNavigatorBase;
import spark.effects.Animate;
import spark.effects.Fade;
import spark.effects.animation.MotionPath;
import spark.effects.animation.SimpleMotionPath;
import spark.effects.easing.IEaser;
import spark.effects.easing.Sine;
import spark.primitives.BitmapImage;
import spark.utils.BitmapUtil;

use namespace mx_internal;

/**
 *  Dispatched when the transition starts.
 */
[Event(name="transitionStart", type="flash.events.Event")]

/**
 *  Dispatched when the transition is complete.
 */
[Event(name="transitionEnd", type="flash.events.Event")]


/**
 *  The ViewTransitionBase class serves as the base class for all stock view 
 *  transitions.  It is not intended to be used as a transition on its own.
 *  
 *  In addition to providing common convenience and helper methods used by 
 *  view transitions this class also provides a default action bar transition 
 *  sequence.
 * 
 *  <p>When a view transition is initialized, the owning view navigator will 
 *  assign the startView and endView references to the views the transition 
 *  will be animating from and to. In addition, the navigator property will 
 *  be set to reflect the view navigator.</p>
 * 
 *  <p>The lifecycle of a transition starts with the <code>captureStartValues()</code> 
 *  method.  When this method is called, the navigator is currently in the 
 *  start state.  At this point the transition should capture any start values 
 *  or bitmaps that it requires.  Afterwards, a validation pass on the pending 
 *  view and <code>captureEndValues()</code> will be called. At this point the 
 *  transition is to capture any properties or bitmaps representations from the 
 *  pending view.</p>
 *  
 *  <p>At this point <code>prepareForPlay()</code> is called, which allows the transition 
 *  to perform any further preparation (such as preparing a spark effects sequence, 
 *  or positioning transient elements on the display list).</p>
 * 
 *  <p>After one final validation pass (if necessary), <code>play()</code> is invoked 
 *  by the navigator to perform the actual transition. Prior to any animation
 *  starting the <code>FlexEvent.TRANSITION_START</code> event will be dispatched.</p>
 * 
 *  <p>When a transition completes, it is required to dispatch a 
 *  <code>FlexEvent.TRANSITION_END</code> event.</p>
 *  
 *  @langversion 3.0
 *  @playerversion Flash 10
 *  @playerversion AIR 2.5
 *  @productversion Flex 4.5
 */
public class ViewTransitionBase extends EventDispatcher 
{
    
    //--------------------------------------------------------------------------
    //
    //  Constants
    //
    //--------------------------------------------------------------------------
    
    /**
     *  Constant used in tandem with the actionBarTransitionMode property to 
     *  hint the default action bar transition behavior.
     */
    mx_internal static const ACTION_BAR_MODE_FADE:String = "fade";
    
    /**
     *  Constant used in tandem with the actionBarTransitionMode property to 
     *  hint the default action bar transition behavior.
     */
    mx_internal static const ACTION_BAR_MODE_FADE_AND_SLIDE:String = "fadeAndSlide";
    
    /**
     *  Constant used in tandem with the actionBarTransitionMode property to 
     *  hint the default action bar transition behavior.
     */
    mx_internal static const ACTION_BAR_MODE_NONE:String = "none";
    
    //--------------------------------------------------------------------------
    //
    //  Constructor
    //
    //--------------------------------------------------------------------------
    
    /**
     *  Constructor.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function ViewTransitionBase()
    {
        super();
    }
    
    //--------------------------------------------------------------------------
    //
    //  Variables
    //
    //--------------------------------------------------------------------------
    
    /**
     *  @private
     *  Flag set when we've determined that we need to transition the navigator
     *  in its entirety and cannot transition the control bars independently.
     */
    protected var consolidatedTransition:Boolean = false;
    
    /**
     *  @private
     *  startView's action bar height.
     */ 
    private var cachedActionBarHeight:Number;
    
    /**
     *  @private
     *  startView's action bar width.
     */ 
    private var cachedActionBarWidth:Number;
    
    /**
     *  @private
     *  Transient display object used to hold temporary bitmap snapshots
     *  during transition.
     */ 
    private var transitionGroup:Group;
    
    /**
     *  @private
     *  Flag to assist with cleanup of any constructs used only for vertical
     *  transitions (e.g. clipping masks).
     */ 
    private var verticalTransition:Boolean;
    
    
    /**
     *  @private
     */
    
    //--------------------------------------------------------------------------
    //
    //  Properties
    //
    //--------------------------------------------------------------------------
    
    //----------------------------------
    //  duration
    //----------------------------------
    
    private var _duration:Number = 250;
    
    /**
     *  Duration of the transition in milliseconds. The default may vary
     *  depending on the transition.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get duration():Number
    {
        return _duration;
    }
    
    /**
     *  @private
     */
    public function set duration(value:Number):void
    {
        _duration = value;
    }
    
    //----------------------------------
    //  easer
    //----------------------------------
    
    private var _easer:IEaser = new Sine(.5);
    
    /**
     *  The easing behavior for this transition. The IEaser object is
     *  generally propagated to the IEffect instance managing the actual
     *  transition animation.
     * 
     *  @default new Sine(.5);
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get easer():IEaser
    {
        return _easer;
    }
    
    /**
     *  @private
     */
    public function set easer(value:IEaser):void
    {
        _easer = value;
    }
    
    //----------------------------------
    //  effect
    //----------------------------------
    
    private var _effect:IEffect;
    
    /**
     *  Provides access to the underlying IEffect instance which the 
     *  transition is using to perform the transition (if any).  This property 
     *  is only valid after the FlexEvent.TRANSITION_START event even has been 
     *  dispatched.
     *
     *  If a transition does not make use of IEffect to perform the transition
     *  this can be null.
     * 
     *  @default null
     *
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    mx_internal function get effect():IEffect
    {
        return _effect;
    }
    
    mx_internal function set effect(value:IEffect):void
    {
        _effect = value;
    }
    
    //----------------------------------
    //  endView
    //----------------------------------
    
    private var _endView:View;
    
    /**
     *  The reference to the view that the navigator is transitioning
     *  to, set by the owning ViewNavigator itself.  This can be null.
     *
     *  @default null
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get endView():View
    {
        return _endView;
    }
    
    /**
     *  @private
     */ 
    public function set endView(value:View):void
    {
        _endView = value;
    }
    
    //----------------------------------
    //  navigator
    //----------------------------------
    
    private var _navigator:ViewNavigator;
    
    /**
     *  Reference to the owning ViewNavigator instance set by the owning
     *  ViewNavigator.
     * 
     *  @default null
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get navigator():ViewNavigator
    {
        return _navigator;
    }
    
    /**
     *  @private
     */
    public function set navigator(value:ViewNavigator):void
    {
        _navigator = value;
    }
    
    //----------------------------------
    //  startView
    //----------------------------------
    
    private var _startView:View;
    
    /**
     *  The currently active view of the view navigator, set by the owning
     *  view navigator itself. This can be null.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get startView():View
    {
        return _startView;
    }
    
    /**
     *  @private
     */
    public function set startView(value:View):void
    {
        _startView = value;
    }
    
    //----------------------------------
    //  transitionControlsWithContent
    //----------------------------------
    
    private var _transitionControlsWithContent:Boolean;
    
    /**
     *  When set to true, the primary view transition
     *  is used to transition the navigator in its entirety,  
     *  and sub-transitions such as the action bar or 
     *  tab bar transitions are not performed.
     *
     *  <p>Note that even when set to false, there are cases
     *  where its not feasible to transition the action bar 
     *  or tab bar, such as when the action bar or 
     *  tab bar does not exist in one of the two views or
     *  if the tab bar or action bar changes size.</p>
     *
     *  @default false
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function get transitionControlsWithContent():Boolean
    {
        return _transitionControlsWithContent;
    }
    
    /**
     *  @private
     */ 
    public function set transitionControlsWithContent(value:Boolean):void
    {
        _transitionControlsWithContent = value;
    }
    
    //--------------------------------------------------------------------------
    //
    //  Private Properties
    //
    //--------------------------------------------------------------------------
    
    //----------------------------------
    //  actionBarTransitionMode
    //----------------------------------
    
    /**
     *  @private
     *  Convenience property used by ViewTransitionBase overrides to hint the behavior of
     *  the default action bar transition as appropriate for the type and nature
     *  of the specific view transition. Can be one either ViewTransitionBase.ACTION_BAR_MODE_FADE, 
     *  ViewTransitionBase.ACTION_BAR_MODE_FADE_AND_SLIDE, or null. If set to fade 
     *  and slide, the actionBarTransitionDirection property is considered by the 
     *  default createActionBarEffect() implementation.
     *
     *  @default ACTION_BAR_MODE_FADE_AND_SLIDE
     */
    mx_internal var actionBarTransitionMode:String = ACTION_BAR_MODE_FADE_AND_SLIDE;
    
    //----------------------------------
    //  actionBarTransitionDirection
    //----------------------------------
    
    /**
     *  @private
     *  Convenience property used by ViewTransitionBase overrides to hint the direction 
     *  of the default action bar transition when the actionBarTransitionMode is set to 
     *  "fadeAndSlide". Can be or null or set to one of the ViewTransitionDirection
     *  constants.  This property is considered by the default createActionBarEffect() 
     *  implementation. 
     *
     *  @default ViewTransitionDirection.LEFT
     */
    mx_internal var actionBarTransitionDirection:String = ViewTransitionDirection.LEFT;
    
    //----------------------------------
    //  cachedNavigatorSnapshot
    //----------------------------------
    
    /**
     *  @private
     *  Cached image of the cumulative view of the owning navigator
     *  captured by the default captureStartValues() implementation.
     *  This snapshot is generally leveraged by transitions that need to
     *  performing a full screen transition.
     */
    mx_internal var cachedNavigator:BitmapImage;
    
    //----------------------------------
    //  cachedActionGroupSnapshot
    //----------------------------------
    
    /**
     *  @private
     *  Cached image of the action bar's action group. This image is 
     *  only captured by default if action group content exists in the
     *  previous view.
     */
    mx_internal var cachedActionGroup:BitmapImage;
    
    //----------------------------------
    //  cachedTitleGroupSnapshot
    //----------------------------------
    
    /**
     *  @private
     *  Cached image of the action bar's title group. This image is 
     *  only captured by default if title group content exists in the
     *  previous view.
     */
    mx_internal var cachedTitleGroup:BitmapImage;
    
    //----------------------------------
    //  cachedNavigationGroupSnapshot
    //----------------------------------
    
    /**
     *  @private
     *  Cached image of the action bar's navigation group. This image is 
     *  only captured by default if navigation group content exists in the
     *  previous view.
     */
    mx_internal var cachedNavigationGroup:BitmapImage;
    
    //----------------------------------
    //  targetNavigator
    //----------------------------------
    
    /**
     *  @private
     *  Convenience property which caches our primary containing navigator, 
     *  this is usually our owning ViewNavigator but may be an outer TabNavigator
     */
    protected var targetNavigator:ViewNavigatorBase;
    
    //----------------------------------
    //  parentNavigator
    //----------------------------------
    
    /**
     *  @private
     *  Convenience property which caches our primary containing navigator, 
     *  this is usually our owning ViewNavigator but may be an outer TabNavigator
     */
    protected var parentNavigator:ViewNavigatorBase;
    
    //----------------------------------
    //  actionBar
    //----------------------------------
    
    /**
     *  @private
     *  Convenience property which caches our associated action bar. 
     */
    protected var actionBar:ActionBar;
    
    //--------------------------------------------------------------------------
    //
    //  Methods
    //
    //--------------------------------------------------------------------------
    
    /**
     *  This method is called by the ViewNavigator during the preparation phase of a transition.
     *  It is invoked when the new view has been fully realized and validated and the 
     *  action bar and tab bar content reflect the state of the new view. It is at 
     *  this point that the transition is to capture any values it requires from the 
     *  pending view. In addition any bitmaps reflecting the state of the new view, tab bar, 
     *  or action bar should be captured if required for animation.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function captureStartValues():void
    {
        // Remember some common references.
        parentNavigator = navigator.parentNavigator;
        targetNavigator = parentNavigator ? parentNavigator : navigator;
        if (navigator is ViewNavigator)
            actionBar = ViewNavigator(navigator).actionBar;
        
        // Determine first if we're able to transition our control bars independently
        // of our view content.  If we are, then capture the necessary action bar
        // bitmap snapshots for use later by our default action bar transition.
        consolidatedTransition = consolidatedTransition ? 
            consolidatedTransition : !canTransitionControlBarContent();
        
        // Snapshot component parts of action bar in preparation for our 
        // default action bar transition, (if appropriate).
        if (!consolidatedTransition && navigator is ViewNavigator)
        {
            if (componentIsVisible(actionBar))
            {
                // Save bounds of action bar. 
                cachedActionBarWidth = actionBar.width;
                cachedActionBarHeight = actionBar.height;
                
                // Snapshot title content of our startView.
                if (actionBar.titleGroup && actionBar.titleGroup.visible)
                    cachedTitleGroup = getSnapshot(actionBar.titleGroup);
                else if (actionBar.titleDisplay
                    && (actionBar.titleDisplay is UIComponent)
                    && UIComponent(actionBar.titleDisplay).visible)
                    cachedTitleGroup = getSnapshot(UIComponent(actionBar.titleDisplay));
                
                // Snapshot actionContent if it's changing between our start and end views.
                if (startView.actionContent != endView.actionContent)
                    cachedActionGroup = getSnapshot(actionBar.actionGroup);
                
                // Snapshot navigationContent if it's changing between our start and end views.
                if (startView.navigationContent != endView.navigationContent)
                    cachedNavigationGroup = getSnapshot(actionBar.navigationGroup);
            }
        }
    }
    
    /**
     *  This method is called by the ViewNavigator during the preparation phase of a transition.
     *  It is invoked when the new view has been fully realized and validated and the 
     *  action bar and tab bar content reflect the state of the new view. It is at 
     *  this point that the transition is to capture any values it requires from the 
     *  pending view. In addition any bitmaps reflecting the state of the new view, tab bar, 
     *  or action bar should be captured if required for animation.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function captureEndValues():void
    {
        // One final check to determine if we will be required to perform a full
        // (consolidated) transition.
        if (!consolidatedTransition)
        {
            consolidatedTransition = 
                ((actionBar.height != cachedActionBarHeight) ||
                    (actionBar.width != cachedActionBarWidth));
        }
    }
    
    /**
     *  This method is called by the ViewNavigator when the transition 
     *  should begin animating.  At this time the transition should dispatch a
     *  FlexEvent.TRANSITION_START event.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function play():void
    {   
        if (effect)
        {
            effect.addEventListener(EffectEvent.EFFECT_END, effectComplete);
            
            // Dispatch TRANSITION_START.
            if (hasEventListener(FlexEvent.TRANSITION_START))
                dispatchEvent(new FlexEvent(FlexEvent.TRANSITION_START));
            
            effect.play();
        }
        else
            transitionComplete();
    }
    
    /**
     *  This method is called by the ViewNavigator during the preparation phase 
     *  of a transition.  It gives the transition the chance to create and
     *  configure the underlying IEffect instance, or to add any transient
     *  elements to the display list (e.g. bitmap placeholders, temporary
     *  containers required during the transition, etc.). One final validation
     *  pass will occur prior to invocation of play() (if required).
     * 
     *  If it is determined that a standard transition can be initiated (e.g one
     *  that transitions the control bars separately from the views), the default
     *  implementation of prepareForPlay() will construct a single Parallel effect
     *  which wraps the individual effect sequences for the view transition, the
     *  action bar transition, and the tab bar transition.  prepareForPlay() makes
     *  use of the helper methods, createActionBarEffect(), createTabBarEffect(),
     *  and createViewEffect() to do so.
     * 
     *  If transitionControlsWithContent is set to true, or if it is determined that
     *  the control bars cannot be transitioned independently, a single effect is 
     *  created to transition the navigator in its entirety from its before and 
     *  after states. In this case, only createConsolidatedEffect() is invoked.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    public function prepareForPlay():void
    {
        if (!consolidatedTransition)
        {
            effect = new Parallel();
            
            // Prepare action bar effect
            if (actionBar)
            {
                var actionBarEffect:IEffect = createActionBarEffect();
                if (actionBarEffect)
                    Parallel(effect).addChild(actionBarEffect);
            }
            
            // Prepare tab bar effect
            if (targetNavigator is TabbedViewNavigator)
            {
                if (TabbedViewNavigator(targetNavigator).tabBar)
                {
                    var tabBarEffect:IEffect = createTabBarEffect();
                    if (tabBarEffect)
                        Parallel(effect).addChild(tabBarEffect);
                }
            }
            
            // Prepare view effect
            var viewEffect:IEffect = createViewEffect();
            if (viewEffect)
                Parallel(effect).addChild(viewEffect);
        }
        else
        {
            // Prepare full transition of navigator in its entirety.
            effect = createConsolidatedEffect();
        }
    }
    
    /**
     *  Called by the default prepareForPlay() implementation, this method 
     *  is responsible for creating the spark effect that should be played on the
     *  action bar when the transition starts.  This method should be
     *  overridden by sub classes if a custom action bar effect is
     *  required.  By default, this returns a basic action bar effect.
     * 
     *  @return An IEffect instance serving as the action bar effect. Will be 
     *  played by the default play() method implementation.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    protected function createActionBarEffect():IEffect
    {
        var slideDistance:Number;
        var animatedProperty:String;
        
        var actionBarSkin:UIComponent = actionBar.skin;
        var fadeOutTargets:Array = new Array();
        var fadeInTargets:Array = new Array();
        
        // Return if we have a noop action bar transition mode.
        if (!actionBar || actionBarTransitionMode == ACTION_BAR_MODE_NONE || 
            !actionBarTransitionMode)
            return null;
        
        transitionGroup = new Group();
        transitionGroup.includeInLayout = false;
        addComponentToContainer(transitionGroup, actionBarSkin);
        transitionGroup.width = actionBar.width;
        transitionGroup.height = actionBar.height;
        
        // Construct our parallel effect.
        var effect:Parallel = new Parallel();
        
        // Calculate the slide distance based on direction.
        switch (actionBarTransitionDirection)
        {           
            case ViewTransitionDirection.RIGHT:
                animatedProperty = "x";
                slideDistance = -actionBar.width / 2.5;
                break;
            
            case ViewTransitionDirection.DOWN:
                animatedProperty = "y";
                slideDistance = -actionBar.height / 2.5;
                transitionGroup.clipAndEnableScrolling = true;
                verticalTransition = true;
                break;
            
            case ViewTransitionDirection.UP:
                animatedProperty = "y";
                slideDistance = actionBar.height / 2.5;
                transitionGroup.clipAndEnableScrolling = true;
                verticalTransition = true;
                break;
            
            case ViewTransitionDirection.LEFT:
            default:
                animatedProperty = "x";
                slideDistance = actionBar.width / 2.5;
                break;
        }
        
        // Suppress slide if our action bar transition behavior is fade-only.
        if (actionBarTransitionMode == ACTION_BAR_MODE_FADE)
            slideDistance = 0;
        
        // If the skin has title content queue new title content for fade in.
        if (actionBar.titleGroup || actionBar.titleDisplay)
        {
            var titleComponent:UIComponent = actionBar.titleGroup;
            
            if (!titleComponent || !titleComponent.visible)
                titleComponent = actionBar.titleDisplay as UIComponent;
            
            if (titleComponent)
            {
                // Initialize titleGroup
                titleComponent.cacheAsBitmap = true;
                titleComponent.alpha = 0;
                titleComponent[animatedProperty] += slideDistance;
                fadeInTargets.push(titleComponent);
                
                if (verticalTransition)
                    transitionGroup.addElementAt(titleComponent, 0);
            }
            
            if (cachedTitleGroup)
                transitionGroup.addElement(cachedTitleGroup);
        }
        
        // If a cache of the navigation group exists, that means the content
        // changed.  In this case the queue cached representation to be faded
        // out.
        if (cachedNavigationGroup)
        {
            transitionGroup.addElement(cachedNavigationGroup);
            if (!verticalTransition)
                fadeOutTargets.push(cachedNavigationGroup);
        }
        
        // If a cache of the action group exists, that means the content
        // changed.  In this case the queue cached representation to be faded
        // out.
        if (cachedActionGroup)
        {
            transitionGroup.addElement(cachedActionGroup);
            if (!verticalTransition)
                fadeOutTargets.push(cachedActionGroup);
        }
        
        // Create fade in animations for navigationContent and actionContent
        // of the next view.
        if (endView)
        {
            if (endView.navigationContent)
            {
                actionBar.navigationGroup[animatedProperty] += slideDistance;
                actionBar.navigationGroup.cacheAsBitmap = true;
                actionBar.navigationGroup.alpha = 0;
                fadeInTargets.push(actionBar.navigationGroup);
                if (verticalTransition)
                    transitionGroup.addElementAt(actionBar.navigationGroup, 0);
            }
            
            if (endView.actionContent)
            {
                actionBar.actionGroup[animatedProperty] += slideDistance;
                actionBar.actionGroup.cacheAsBitmap = true;
                actionBar.actionGroup.alpha = 0;
                fadeInTargets.push(actionBar.actionGroup);
                if (verticalTransition)
                    transitionGroup.addElementAt(actionBar.actionGroup, 0);
            }
        }
        
        // Fade out action and navigation content
        var fadeOut:Animate = new Animate();
        vector = new Vector.<MotionPath>();
        vector.push(new SimpleMotionPath("alpha", 1, 0));
        fadeOut.motionPaths = vector;
        fadeOut.targets = fadeOutTargets;
        fadeOut.duration = duration * .7;
        
        // Fade out and slide old select content
        var animation:Animate = new Animate();
        var vector:Vector.<MotionPath> = new Vector.<MotionPath>();
        vector.push(new SimpleMotionPath("alpha", 1, 0));
        vector.push(new SimpleMotionPath(animatedProperty, null, null, -slideDistance));
        animation.motionPaths = vector;
        animation.easer = new spark.effects.easing.Sine(.7);
        var fadeOutSlideTargets:Array = new Array();
        
        if (cachedTitleGroup)
            fadeOutSlideTargets.push(cachedTitleGroup);
        
        if (cachedActionGroup && verticalTransition)
            fadeOutSlideTargets.push(cachedActionGroup);
        
        if (cachedNavigationGroup && verticalTransition)
            fadeOutSlideTargets.push(cachedNavigationGroup);
        
        if (fadeOutSlideTargets.length)
        {
            animation.targets = fadeOutSlideTargets;
            animation.duration = duration;
            effect.addChild(animation);
        }
        
        // Construct animation for our fade in and slide elements.
        var fadeAndSlide:Animate = new Animate();
        vector = new Vector.<MotionPath>();
        vector.push(new SimpleMotionPath("alpha", 0, 1));
        vector.push(new SimpleMotionPath(animatedProperty, null, null, -slideDistance));
        fadeAndSlide.motionPaths = vector;
        fadeAndSlide.easer = new spark.effects.easing.Sine(.7);
        fadeAndSlide.targets = fadeInTargets;
        fadeAndSlide.duration = duration;
        
        // Add effects to the parallel effect
        effect.addChild(fadeOut);
        effect.addChild(fadeAndSlide);
        
        // Ensure bitmaps are rendered prior to invocation of our effect.
        transitionGroup.validateNow();
        
        return effect;
    }
    
    /**
     *  Called by the default prepareForPlay() implementation, this method 
     *  is responsible for creating the spark effect that should be played 
     *  on the tab bar when the transition starts.  This method should be
     *  overridden by sub classes.  By default, this returns null.
     * 
     *  @return An IEffect instance serving as the tab bar transition. Will be played
     *  by the default play() method implementation.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    protected function createTabBarEffect():IEffect
    {
        return null;
    }
    
    /**
     *  Called by the default prepareForPlay() implementation, this method 
     *  is responsible for creating the spark effect that should be played 
     *  on the current and next view when the transition starts.  This method
     *  should be overridden by sub classes.  By default, this returns null.
     * 
     *  @return An IEffect instance serving as the view transition. Will be played
     *  by the default play() method implementation.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    protected function createViewEffect():IEffect
    {
        return null;
    }
    
    /**
     *  Called by the default prepareForPlay() implementation, this method 
     *  is responsible for creating the spark effect that will be played to
     *  transition the entire navigator (inclusive of the control bar content) 
     *  when necessary.  This method should be overridden by sub classes.  
     *  By default, this returns null.
     * 
     *  @return An IEffect instance serving as the view transition. Will be played
     *  by the default play() method implementation.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    protected function createConsolidatedEffect():IEffect
    {
        return null;
    }
    
    /**
     *  Called by the transition to denote that the effect object 
     *  has finished executing, dispatches a FlexEvent.TRANSITION_END event.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    protected function transitionComplete():void
    {
        cleanUp();
        
        if (hasEventListener(FlexEvent.TRANSITION_END))
            dispatchEvent(new FlexEvent(FlexEvent.TRANSITION_END));
    }
    
    /**
     *  Called after the transition is complete, responsible for 
     *  releasing any references and temporary constructs used by the
     *  transition.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */
    protected function cleanUp():void
    {
        if (!consolidatedTransition && transitionGroup)
        {               
            if (cachedTitleGroup)
                transitionGroup.removeElement(cachedTitleGroup);
            
            if (cachedNavigationGroup)
                transitionGroup.removeElement(cachedNavigationGroup);
            
            if (cachedActionGroup)
            {
                transitionGroup.removeElement(cachedActionGroup);
                actionBar.actionGroup.cacheAsBitmap = false;
            }
            
            // Restore title group and title content to their original state.
            if (actionBar && actionBar.titleGroup && actionBar.titleGroup.visible)
                actionBar.titleGroup.cacheAsBitmap = false;
            
            if (actionBar && actionBar.titleDisplay
                && (actionBar.titleDisplay is DisplayObject)
                && DisplayObject(actionBar.titleDisplay).visible)
            {
                DisplayObject(actionBar.titleDisplay).cacheAsBitmap = false;
            }
            
            // Restore title group and title content to their original home.
            if (actionBar && verticalTransition)
            {
                var titleComponent:UIComponent = actionBar.titleGroup;
                if (!titleComponent || !titleComponent.visible)
                    titleComponent = actionBar.titleDisplay as UIComponent;
                
                if (titleComponent)
                {
                    transitionGroup.removeElement(titleComponent);
                    addComponentToContainer(titleComponent, actionBar.skin);
                }
            }
            
            // Restore navigation group to their proper home.
            if (endView.navigationContent && actionBar && verticalTransition)
            {
                transitionGroup.removeElement(actionBar.navigationGroup);
                if (actionBar.titleDisplay)
                {
                    var childIndex:uint = actionBar.skin.getChildIndex(actionBar.titleDisplay as DisplayObject);
                    addComponentToContainerAt(actionBar.navigationGroup, actionBar.skin, childIndex);
                }
                else
                    addComponentToContainer(actionBar.navigationGroup, actionBar.skin);
            }
            
            // Restore action group to their proper home.
            if (endView.actionContent && actionBar && verticalTransition)
            {
                transitionGroup.removeElement(actionBar.actionGroup);
                if (actionBar.titleDisplay)
                {
                    childIndex = actionBar.skin.getChildIndex(actionBar.titleDisplay as DisplayObject);
                    addComponentToContainerAt(actionBar.actionGroup, actionBar.skin, childIndex);
                }
                else
                    addComponentToContainer(actionBar.actionGroup, actionBar.skin);
            }
            
            removeComponentFromContainer(transitionGroup, actionBar.skin);
            
            if (actionBar) 
                actionBar.skin.scrollRect = null;
            
            verticalTransition = false;
            cachedActionBarHeight = 0;
            cachedActionBarWidth = 0;
            
            transitionGroup = null;
            cachedTitleGroup = null;
            cachedNavigationGroup = null;
            cachedActionGroup = null;
        }
        
        consolidatedTransition = false;
        actionBar = null;
        parentNavigator = null;
        targetNavigator = null;
        navigator = null;
        startView = null;
        endView = null;
    }
    
    /**
     *  Helper method used to determine if we can safely transition our
     *  control bar content independently of our views.
     * 
     *  <p> We will not be able to transition our action bar independently if 
     *  our containing navigator is a TabbedViewNavigator and its tabBar's 
     *  visibility changes between views, if the value of the overlayControls
     *  flag changes between views, or if the size/visibility of the action 
     *  bar changes between views.</p>
     * 
     *  @return false if we determine controls bars between views are 
     *  incompatible in some way.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */ 
    protected function canTransitionControlBarContent():Boolean
    {               
        // Short circuit if we've already been asked to not consider
        // control bars during transition.
        if (transitionControlsWithContent)
            return false;
        
        // Test for visibility or size of tab bar changing.
        if (targetNavigator is TabbedViewNavigator)
        {
            var tabBar:ButtonBarBase = TabbedViewNavigator(targetNavigator).tabBar;
            if (componentIsVisible(tabBar) != endView.tabBarVisible)
                return false;
        }
        
        // Test for visibility or size of action bar changing.
        if (navigator is ViewNavigator)
        {
            var actionBar:ActionBar = ViewNavigator(navigator).actionBar;
            if (componentIsVisible(actionBar) != endView.actionBarVisible)
                return false;
        }
        
        // Test for value of overlayControls changing.
        if (startView.overlayControls != endView.overlayControls)
            return false;
        
        return true;
    }
    
    /**
     *  Helper method used to render snap shots of on screen elements in 
     *  preparation for transitioning.  The bitmap is returned in the form
     *  of a BitmapImage.
     * 
     *  @param target Display object to capture.
     *  @return BitmapImage representation of the target.
     * 
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 2.5
     *  @productversion Flex 4.5
     */ 
    protected function getSnapshot(target:UIComponent):BitmapImage
    {       
        var snapShot:BitmapImage = new BitmapImage();
        
        // Ensure bitmap leverages its own display object for performance
        // reasons.
        snapShot.alwaysCreateDisplayObject = true;
        
        // Capture image, with consideration for transform and color matrix.
        var bounds:Rectangle = new Rectangle();
        snapShot.source = BitmapUtil.getSnapshot(target, bounds, true);
        
        // Size and offset snapShot to match our image bounds data.
        snapShot.width = bounds.width;
        snapShot.height = bounds.height;
        snapShot.x = target.x + bounds.left;
        snapShot.y = target.y + bounds.top;
        
        // Exclude from layout.
        snapShot.includeInLayout = false;
        
        return snapShot; 
    }
    
    //--------------------------------------------------------------------------
    //
    //  Private Methods
    //
    //--------------------------------------------------------------------------
    
    /**
     * @private
     */ 
    private function effectComplete(event:EffectEvent):void
    {
        effect.removeEventListener(EffectEvent.EFFECT_END, effectComplete);
        transitionComplete();
        effect = null;
    }
    
    /**
     * @private
     * Helper method to test whether a component is visible to user.
     */ 
    protected function componentIsVisible(component:UIComponent):Boolean
    {
        return component && component.visible && 
            component.width && component.height && component.alpha;
    }
    
    /**
     *  @private
     *  Helper method to add a UIComponent instance to either an IVisualElementContainer
     *  or DisplayObjectContainer. 
     */ 
    protected function addComponentToContainerAt(component:UIComponent, 
                                                 container:UIComponent, 
                                                 index:int):void
    {
        if (container is IVisualElementContainer)
            IVisualElementContainer(container).addElementAt(component, index);
        else
            container.addChildAt(component, index);
    }
    
    /**
     *  @private
     *  Helper method to add a UIComponent instance to either an IVisualElementContainer
     *  or DisplayObjectContainer.
     */ 
    protected function addComponentToContainer(component:UIComponent, 
                                               container:UIComponent):void
    {
        if (container is IVisualElementContainer)
            IVisualElementContainer(container).addElement(component);
        else
            container.addChild(component);
    }
    
    /**
     *  @private
     *  Helper method to remove a UIComponent instance from either an IVisualElementContainer
     *  or DisplayObjectContainer.
     */ 
    protected function removeComponentFromContainer(component:UIComponent, 
                                                    container:UIComponent):void
    {
        if (container is IVisualElementContainer)
            IVisualElementContainer(container).removeElement(component);
        else
            container.removeChild(component);
    }
    
    /**
     *  @private
     *  Helper method to set the child index of the given component.
     */ 
    protected function setComponentChildIndex(component:UIComponent, 
                                              container:UIComponent, 
                                              index:int):void
    {
        if (container is IVisualElementContainer)
            IVisualElementContainer(container).setElementIndex(component, index);
        else
            container.setChildIndex(component, index);
    }
    
}

    
}
