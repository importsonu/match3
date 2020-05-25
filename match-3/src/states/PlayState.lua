--[[
    GD50 2018
    Match-3 Remake

    -- BeginGameState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    State in which we can actually play, moving around a grid cursor that
    can swap two tiles; when two tiles make a legal swap (a swap that results
    in a valid match), perform the swap and destroy all matched tiles, adding
    their values to the player's point score. The player can continue playing
    until they exceed the number of points needed to get to the next level
    or until the time runs out, at which point they are brought back to the
    main menu or the score entry menu if they made the top 10.
]]

PlayState = Class{__includes = BaseState}

function PlayState:init()
    -- start our transition alpha at full, so we fade in
    self.transitionAlpha = 255

    -- position in the grid which we're highlighting
    self.boardHighlightX = 0
    self.boardHighlightY = 0

    -- timer used to switch the highlight rect's color
    self.rectHighlighted = false

    -- flag to show whether we're able to process input (not swapping or clearing)
    self.canInput = true

    -- tile we're currently highlighting (preparing to swap)
    self.highlightedTile = nil

    self.score = 0
    self.timer = 60

    -- set our Timer class to turn highlight on cursor on and off
    Timer.every(0.5, function()
        self.rectHighlighted = not self.rectHighlighted
    end)

    -- subtract 1 from timer every second
    Timer.every(1, function()
        self.timer = self.timer - 1
    end)
end

function PlayState:enter(def)
    -- grab level # from the def we're passed
    self.level = def.level

    -- spawn a board and place it toward the right
    self.board = def.board or Board(VIRTUAL_WIDTH - 272, 16)

    -- grab score from def if it was passed
    self.score = def.score or 0

    -- score we have to reach to get to the next level
    self.scoreGoal = self.level * 1.25 * 1000
end

function PlayState:update(dt)
    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end

    -- go back to start if time runs out
    if self.timer <= 0 then
        gStateMachine:change('start')
    end

    -- go to next level if we surpass score goal
    if self.score >= self.scoreGoal then
        gStateMachine:change('begin-game', {
            level = self.level + 1,
            score = self.score
        })
    end

    if self.canInput then
        -- move cursor around based on bounds of grid, playing sounds
        if love.keyboard.wasPressed('up') then
            self.boardHighlightY = math.max(0, self.boardHighlightY - 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('down') then
            self.boardHighlightY = math.min(7, self.boardHighlightY + 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('left') then
            self.boardHighlightX = math.max(0, self.boardHighlightX - 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('right') then
            self.boardHighlightX = math.min(7, self.boardHighlightX + 1)
            gSounds['select']:play()
        end

        -- if we've pressed enter, to select or deselect a tile...
        if love.keyboard.wasPressed('enter') or love.keyboard.wasPressed('return') then
            -- if same tile as currently highlighted, deselect
            local x = self.boardHighlightX
            local y = self.boardHighlightY
            
            if not self.highlightedTile then
                self.highlightedTile = self.board.tiles[(y * 8 + x) + 1]
            elseif self.highlightedTile == self.board.tiles[(y * 8 + x) + 1] then
                self.highlightedTile = nil
            else
                -- swap grid positions of tiles
                local tempX = self.highlightedTile.gridX
                local tempY = self.highlightedTile.gridY

                local newTile = self.board.tiles[(y * 8 + x) + 1]

                self.highlightedTile.gridX = newTile.gridX
                self.highlightedTile.gridY = newTile.gridY
                newTile.gridX = tempX
                newTile.gridY = tempY

                -- swap tiles in the tiles table
                self.board.tiles[(self.highlightedTile.gridY - 1) * 8 + self.highlightedTile.gridX] =
                    self.highlightedTile

                self.board.tiles[(newTile.gridY - 1) * 8 + newTile.gridX] = newTile

                -- tween coordinates between the two so they swap
                Timer.tween(0.1, {
                    [self.highlightedTile] = {x = newTile.x, y = newTile.y},
                    [newTile] = {x = self.highlightedTile.x, y = self.highlightedTile.y}
                })
                -- once the swap is finished, we can tween falling blocks as needed
                :finish(function()
                    self.highlightedTile = nil

                    -- if we have any matches, remove them and tween the falling blocks that result
                    local matches = self.board:calculateMatches()
                    
                    if matches then
                        
                        -- add score for each match
                        for k, match in pairs(matches) do
                            self.score = self.score + #match * 50
                        end

                        -- remove any tiles that matched from the board, making empty spaces
                        self.board:removeMatches()

                        -- gets a table with tween values for tiles that should now fall
                        local tilesToFall = self.board:getFallingTiles()

                        -- first, tween the falling tiles over 0.25s
                        Timer.tween(0.25, tilesToFall):finish(function()
                            local newTiles = self.board:getNewTiles()
                            
                            -- then, tween new tiles that spawn from the ceiling over 0.25s to fill in
                            -- the new upper gaps that exist
                            Timer.tween(0.25, newTiles):finish(function()
                                self.canInput = true
                            end)
                        end)
                    -- if no matches, we can continue playing
                    else
                        self.canInput = true
                    end
                end)
            end
        end
    end

    Timer.update(dt)
end

function PlayState:render()
    -- render board of tiles
    self.board:render()

    -- render highlighted tile if it exists
    if self.highlightedTile then
        -- multiply so drawing white rect makes it brighter
        love.graphics.setBlendMode('add')

        love.graphics.setColor(255, 255, 255, 96)
        love.graphics.rectangle('fill', (self.highlightedTile.gridX - 1) * 32 + (VIRTUAL_WIDTH - 272),
            (self.highlightedTile.gridY - 1) * 32 + 16, 32, 32, 4)

        -- back to alpha
        love.graphics.setBlendMode('alpha')
    end

    -- render highlight rect color based on timer
    if self.rectHighlighted then
        love.graphics.setColor(217, 87, 99, 255)
    else
        love.graphics.setColor(172, 50, 50, 255)
    end

    -- draw actual cursor rect
    love.graphics.rectangle('line', self.boardHighlightX * 32 + (VIRTUAL_WIDTH - 272),
        self.boardHighlightY * 32 + 16, 32, 32, 4)

    -- GUI text
    love.graphics.setColor(99, 155, 255, 255)
    love.graphics.setFont(gFonts['medium'])
    love.graphics.print('Level: ' .. tostring(self.level), 24, 24)
    love.graphics.print('Score: ' .. tostring(self.score), 24, 48)
    love.graphics.print('Goal : ' .. tostring(self.scoreGoal), 24, 72)
    love.graphics.print('Timer: ' .. tostring(self.timer), 24, 96)
end
