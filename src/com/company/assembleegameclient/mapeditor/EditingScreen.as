﻿package com.company.assembleegameclient.mapeditor
{
    import com.company.assembleegameclient.editor.CommandEvent;
    import com.company.assembleegameclient.editor.CommandList;
    import com.company.assembleegameclient.editor.CommandQueue;
    import com.company.assembleegameclient.map.GroundLibrary;
    import com.company.assembleegameclient.map.RegionLibrary;
    import com.company.assembleegameclient.objects.ObjectLibrary;
    import com.company.assembleegameclient.screens.AccountScreen;
    import com.company.assembleegameclient.ui.dropdown.DropDown;
    import com.company.util.IntPoint;
    import com.company.util.SpriteUtil;
    import com.hurlant.util.Base64;

    import flash.display.Sprite;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.geom.Rectangle;
    import flash.net.FileFilter;
    import flash.net.FileReference;
    import flash.utils.ByteArray;

    import kabam.lib.json.JsonParser;
    import kabam.rotmg.core.StaticInjectorContext;
    import kabam.rotmg.ui.view.components.ScreenBase;

    import net.hires.debug.Stats;

    public class EditingScreen extends Sprite
    {
        private static const MAP_Y:int = ((600 - MEMap.SIZE) - 10);//78
        public static const stats_:Stats = new Stats();
        public var commandMenu_:MECommandMenu;
        private var commandQueue_:CommandQueue;
        public var meMap_:MEMap;
        public var infoPane_:InfoPane;
        public var chooserDrowDown_:DropDown;
        public var groundChooser_:GroundChooser;
        public var objChooser_:ObjectChooser;
        public var regionChooser_:RegionChooser;
        public var chooser_:Chooser;
        public var filename_:String = null;
        private var json:JsonParser;
        private var tilesBackup:Vector.<METile>;
        private var loadedFile_:FileReference = null;

        public function EditingScreen()
        {
            addChild(new ScreenBase());
            addChild(new AccountScreen());
            this.json = StaticInjectorContext.getInjector().getInstance(JsonParser);
            this.commandMenu_ = new MECommandMenu();
            this.commandMenu_.x = 15;
            this.commandMenu_.y = (MAP_Y - 30);
            this.commandMenu_.addEventListener(CommandEvent.UNDO_COMMAND_EVENT, this.onUndo);
            this.commandMenu_.addEventListener(CommandEvent.REDO_COMMAND_EVENT, this.onRedo);
            this.commandMenu_.addEventListener(CommandEvent.CLEAR_COMMAND_EVENT, this.onClear);
            this.commandMenu_.addEventListener(CommandEvent.LOAD_COMMAND_EVENT, this.onLoad);
            this.commandMenu_.addEventListener(CommandEvent.SAVE_COMMAND_EVENT, this.onSave);
            this.commandMenu_.addEventListener(CommandEvent.TEST_COMMAND_EVENT, this.onTest);
            this.commandMenu_.addEventListener(CommandEvent.SELECT_COMMAND_EVENT, this.onMenuSelect);
            addChild(this.commandMenu_);
            this.commandQueue_ = new CommandQueue();
            this.meMap_ = new MEMap();
            this.meMap_.addEventListener(TilesEvent.TILES_EVENT, this.onTilesEvent);
            this.meMap_.x = ((800 / 2) - (MEMap.SIZE / 2));
            this.meMap_.y = MAP_Y;
            addChild(this.meMap_);
            this.infoPane_ = new InfoPane(this.meMap_);
            this.infoPane_.x = 4;
            this.infoPane_.y = ((600 - InfoPane.HEIGHT) - 10);
            addChild(this.infoPane_);
            this.chooserDrowDown_ = new DropDown(new <String>["Ground", "Objects", "Regions"], Chooser.WIDTH, 26);
            this.chooserDrowDown_.x = ((this.meMap_.x + MEMap.SIZE) + 4);
            this.chooserDrowDown_.y = MAP_Y;
            this.chooserDrowDown_.addEventListener(Event.CHANGE, this.onDropDownChange);
            addChild(this.chooserDrowDown_);
            this.groundChooser_ = new GroundChooser();
            this.groundChooser_.x = this.chooserDrowDown_.x;
            this.groundChooser_.y = ((this.chooserDrowDown_.y + this.chooserDrowDown_.height) + 4);
            this.chooser_ = this.groundChooser_;
            addChild(this.groundChooser_);
            this.objChooser_ = new ObjectChooser();
            this.objChooser_.x = this.chooserDrowDown_.x;
            this.objChooser_.y = ((this.chooserDrowDown_.y + this.chooserDrowDown_.height) + 4);
            this.regionChooser_ = new RegionChooser();
            this.regionChooser_.x = this.chooserDrowDown_.x;
            this.regionChooser_.y = ((this.chooserDrowDown_.y + this.chooserDrowDown_.height) + 4);
        }

        private function onTilesEvent(_arg1:TilesEvent):void
        {
            var _local2:IntPoint;
            var _local3:METile;
            var _local4:int;
            var _local5:String;
            var _local6:EditTileProperties;
            var _local7:Vector.<METile>;
            _local2 = _arg1.tiles_[0];
            switch (this.commandMenu_.getCommand())
            {
                case MECommandMenu.DRAW_COMMAND:
                    this.addModifyCommandList(_arg1.tiles_, this.chooser_.layer_, this.chooser_.selectedType());
                    break;
                case MECommandMenu.ERASE_COMMAND:
                    this.addModifyCommandList(_arg1.tiles_, this.chooser_.layer_, -1);
                    break;
                case MECommandMenu.SAMPLE_COMMAND:
                    _local4 = this.meMap_.getType(_local2.x_, _local2.y_, this.chooser_.layer_);
                    if (_local4 == -1)
                    {
                        return;
                    }
                    this.chooser_.setSelectedType(_local4);
                    this.commandMenu_.setCommand(MECommandMenu.DRAW_COMMAND);
                    break;
                case MECommandMenu.EDIT_COMMAND:
                    _local5 = this.meMap_.getObjectName(_local2.x_, _local2.y_);
                    _local6 = new EditTileProperties(_arg1.tiles_, _local5);
                    _local6.addEventListener(Event.COMPLETE, this.onEditComplete);
                    addChild(_local6);
                    break;
                case MECommandMenu.CUT_COMMAND:
                    this.tilesBackup = new Vector.<METile>();
                    _local7 = new Vector.<METile>();
                    for each (_local2 in _arg1.tiles_)
                    {
                        _local3 = this.meMap_.getTile(_local2.x_, _local2.y_);
                        if (_local3 != null)
                        {
                            _local3 = _local3.clone();
                        }
                        this.tilesBackup.push(_local3);
                        _local7.push(null);
                    }
                    this.addPasteCommandList(_arg1.tiles_, _local7);
                    this.meMap_.freezeSelect();
                    this.commandMenu_.setCommand(MECommandMenu.PASTE_COMMAND);
                    break;
                case MECommandMenu.COPY_COMMAND:
                    this.tilesBackup = new Vector.<METile>();
                    for each (_local2 in _arg1.tiles_)
                    {
                        _local3 = this.meMap_.getTile(_local2.x_, _local2.y_);
                        if (_local3 != null)
                        {
                            _local3 = _local3.clone();
                        }
                        this.tilesBackup.push(_local3);
                    }
                    this.meMap_.freezeSelect();
                    this.commandMenu_.setCommand(MECommandMenu.PASTE_COMMAND);
                    break;
                case MECommandMenu.PASTE_COMMAND:
                    this.addPasteCommandList(_arg1.tiles_, this.tilesBackup);
                    break;
            }
            this.meMap_.draw();
        }

        private function onEditComplete(_arg1:Event):void
        {
            var _local2:EditTileProperties = (_arg1.currentTarget as EditTileProperties);
            this.addObjectNameCommandList(_local2.tiles_, _local2.getObjectName());
        }

        private function addModifyCommandList(_arg1:Vector.<IntPoint>, _arg2:int, _arg3:int):void
        {
            var _local5:IntPoint;
            var _local6:int;
            var _local4:CommandList = new CommandList();
            for each (_local5 in _arg1)
            {
                _local6 = this.meMap_.getType(_local5.x_, _local5.y_, _arg2);
                if (_local6 != _arg3)
                {
                    _local4.addCommand(new MEModifyCommand(this.meMap_, _local5.x_, _local5.y_, _arg2, _local6, _arg3));
                }
            }
            if (_local4.empty())
            {
                return;
            }
            this.commandQueue_.addCommandList(_local4);
        }

        private function addPasteCommandList(_arg1:Vector.<IntPoint>, _arg2:Vector.<METile>):void
        {
            var _local5:IntPoint;
            var _local6:METile;
            var _local3:CommandList = new CommandList();
            var _local4:int;
            for each (_local5 in _arg1)
            {
                if (_local4 >= _arg2.length)
                {
                    break;
                }
                _local6 = this.meMap_.getTile(_local5.x_, _local5.y_);
                _local3.addCommand(new MEReplaceCommand(this.meMap_, _local5.x_, _local5.y_, _local6, _arg2[_local4]));
                _local4++;
            }
            if (_local3.empty())
            {
                return;
            }
            this.commandQueue_.addCommandList(_local3);
        }

        private function addObjectNameCommandList(_arg1:Vector.<IntPoint>, _arg2:String):void
        {
            var _local4:IntPoint;
            var _local5:String;
            var _local3:CommandList = new CommandList();
            for each (_local4 in _arg1)
            {
                _local5 = this.meMap_.getObjectName(_local4.x_, _local4.y_);
                if (_local5 != _arg2)
                {
                    _local3.addCommand(new MEObjectNameCommand(this.meMap_, _local4.x_, _local4.y_, _local5, _arg2));
                }
            }
            if (_local3.empty())
            {
                return;
            }
            this.commandQueue_.addCommandList(_local3);
        }

        private function onDropDownChange(_arg1:Event):void
        {
            switch (this.chooserDrowDown_.getValue())
            {
                case "Ground":
                    SpriteUtil.safeAddChild(this, this.groundChooser_);
                    SpriteUtil.safeRemoveChild(this, this.objChooser_);
                    SpriteUtil.safeRemoveChild(this, this.regionChooser_);
                    this.chooser_ = this.groundChooser_;
                    return;
                case "Objects":
                    SpriteUtil.safeRemoveChild(this, this.groundChooser_);
                    SpriteUtil.safeAddChild(this, this.objChooser_);
                    SpriteUtil.safeRemoveChild(this, this.regionChooser_);
                    this.chooser_ = this.objChooser_;
                    return;
                case "Regions":
                    SpriteUtil.safeRemoveChild(this, this.groundChooser_);
                    SpriteUtil.safeRemoveChild(this, this.objChooser_);
                    SpriteUtil.safeAddChild(this, this.regionChooser_);
                    this.chooser_ = this.regionChooser_;
                    return;
            }
        }

        private function onUndo(_arg1:CommandEvent):void
        {
            this.commandQueue_.undo();
            this.meMap_.draw();
        }

        private function onRedo(_arg1:CommandEvent):void
        {
            this.commandQueue_.redo();
            this.meMap_.draw();
        }

        private function onClear(_arg1:CommandEvent):void
        {
            var _local4:IntPoint;
            var _local5:METile;
            var _local2:Vector.<IntPoint> = this.meMap_.getAllTiles();
            var _local3:CommandList = new CommandList();
            for each (_local4 in _local2)
            {
                _local5 = this.meMap_.getTile(_local4.x_, _local4.y_);
                if (_local5 != null)
                {
                    _local3.addCommand(new MEClearCommand(this.meMap_, _local4.x_, _local4.y_, _local5));
                }
            }
            if (_local3.empty())
            {
                return;
            }
            this.commandQueue_.addCommandList(_local3);
            this.meMap_.draw();
            this.filename_ = null;
        }

        private function createMapJSON():String
        {
            var _local7:int;
            var _local8:METile;
            var _local9:Object;
            var _local10:String;
            var _local11:int;
            var _local1:Rectangle = this.meMap_.getTileBounds();
            if (_local1 == null)
            {
                return (null);
            }
            var _local2:Object = {};
            _local2["width"] = int(_local1.width);
            _local2["height"] = int(_local1.height);
            var _local3:Object = {};
            var _local4:Array = [];
            var _local5:ByteArray = new ByteArray();
            var _local6:int = _local1.y;
            while (_local6 < _local1.bottom)
            {
                _local7 = _local1.x;
                while (_local7 < _local1.right)
                {
                    _local8 = this.meMap_.getTile(_local7, _local6);
                    _local9 = this.getEntry(_local8);
                    _local10 = this.json.stringify(_local9);
                    if (!_local3.hasOwnProperty(_local10))
                    {
                        _local11 = _local4.length;
                        _local3[_local10] = _local11;
                        _local4.push(_local9);
                    }
                    else
                    {
                        _local11 = _local3[_local10];
                    }
                    _local5.writeShort(_local11);
                    _local7++;
                }
                _local6++;
            }
            _local2["dict"] = _local4;
            _local5.compress();
            _local2["data"] = Base64.encodeByteArray(_local5);
            return (this.json.stringify(_local2));
        }

        private function onSave(_arg1:CommandEvent):void
        {
            var _local2:String = this.createMapJSON();
            if (_local2 == null)
            {
                return;
            }
            new FileReference().save(_local2, (((this.filename_ == null)) ? "map.jm" : this.filename_));
        }

        private function getEntry(_arg1:METile):Object
        {
            var _local3:Vector.<int>;
            var _local4:String;
            var _local5:Object;
            var _local2:Object = {};
            if (_arg1 != null)
            {
                _local3 = _arg1.types_;
                if (_local3[Layer.GROUND] != -1)
                {
                    _local4 = GroundLibrary.getIdFromType(_local3[Layer.GROUND]);
                    _local2["ground"] = _local4;
                }
                if (_local3[Layer.OBJECT] != -1)
                {
                    _local4 = ObjectLibrary.getIdFromType(_local3[Layer.OBJECT]);
                    _local5 = {"id": _local4};
                    if (_arg1.objName_ != null)
                    {
                        _local5["name"] = _arg1.objName_;
                    }
                    _local2["objs"] = [_local5];
                }
                if (_local3[Layer.REGION] != -1)
                {
                    _local4 = RegionLibrary.getIdFromType(_local3[Layer.REGION]);
                    _local2["regions"] = [{"id": _local4}];
                }
            }
            return (_local2);
        }

        private function onLoad(_arg1:CommandEvent):void
        {
            this.loadedFile_ = new FileReference();
            this.loadedFile_.addEventListener(Event.SELECT, this.onFileBrowseSelect);
            this.loadedFile_.browse([new FileFilter("JSON Map (*.jm)", "*.jm")]);
        }

        private function onFileBrowseSelect(event:Event):void
        {
            var loadedFile:FileReference = (event.target as FileReference);
            loadedFile.addEventListener(Event.COMPLETE, this.onFileLoadComplete);
            loadedFile.addEventListener(IOErrorEvent.IO_ERROR, this.onFileLoadIOError);
            try
            {
                loadedFile.load();
            }
            catch (e:Error)
            {
            }
        }

        private function onFileLoadComplete(_arg1:Event):void
        {
            var _local9:int;
            var _local11:int;
            var _local12:Object;
            var _local13:Array;
            var _local14:Array;
            var _local15:Object;
            var _local16:Object;
            var _local2:FileReference = (_arg1.target as FileReference);
            this.filename_ = _local2.name;
            var _local3:Object = this.json.parse(_local2.data.toString());
            var _local4:int = _local3["width"];
            var _local5:int = _local3["height"];
            var _local6:Rectangle = new Rectangle(
                    int(((MEMap.NUM_SQUARES / 2) - (_local4 / 2))),
                    int(((MEMap.NUM_SQUARES / 2) - (_local5 / 2))),
                    _local4,
                    _local5
            );
            this.meMap_.clear();
            this.commandQueue_.clear();
            var _local7:Array = _local3["dict"];
            var _local8:ByteArray = Base64.decodeToByteArray(_local3["data"]);
            _local8.uncompress();
            var _local10:int = _local6.y;
            while (_local10 < _local6.bottom)
            {
                _local11 = _local6.x;
                while (_local11 < _local6.right)
                {
                    _local12 = _local7[_local8.readShort()];
                    if (_local12.hasOwnProperty("ground"))
                    {
                        _local9 = GroundLibrary.idToType_[_local12["ground"]];
                        this.meMap_.modifyTile(_local11, _local10, Layer.GROUND, _local9);
                    }
                    _local13 = _local12["objs"];
                    if (_local13 != null)
                    {
                        for each (_local15 in _local13)
                        {
                            if (ObjectLibrary.idToType_.hasOwnProperty(_local15["id"]))
                            {
                                _local9 = ObjectLibrary.idToType_[_local15["id"]];
                                this.meMap_.modifyTile(_local11, _local10, Layer.OBJECT, _local9);
                                if (_local15.hasOwnProperty("name"))
                                {
                                    this.meMap_.modifyObjectName(_local11, _local10, _local15["name"]);
                                }
                            }
                        }
                    }
                    _local14 = _local12["regions"];
                    if (_local14 != null)
                    {
                        for each (_local16 in _local14)
                        {
                            _local9 = RegionLibrary.idToType_[_local16["id"]];
                            this.meMap_.modifyTile(_local11, _local10, Layer.REGION, _local9);
                        }
                    }
                    _local11++;
                }
                _local10++;
            }
            this.meMap_.draw();
        }

        private function onFileLoadIOError(_arg1:Event):void
        {
        }

        private function onTest(_arg1:Event):void
        {
            dispatchEvent(new MapTestEvent(this.createMapJSON()));
        }

        private function onMenuSelect(_arg1:Event):void
        {
            if (this.meMap_ != null)
            {
                this.meMap_.clearSelect();
            }
        }
    }
}

