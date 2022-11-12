-- Setup commands
CREATE SCHEMA IF NOT EXISTS pong;

DROP TABLE IF EXISTS pong.screen;
CREATE TABLE IF NOT EXISTS pong.screen (rowNumber, cell1, cell2, cell3, cell4, cell5, cell6, cell7, cell8, cell9) AS VALUES
(1, '', '', '', '', '', '', '', '', ''),
(2, '', '', '', '', '', '', '', '', ''),
(3, '', '', '', '', '', '', '', '', ''),
(4, '#', '', '', '', '', '', '', '', '#'),
(5, '#', '', '', '', '@', '', '', '', '#'),
(6, '#', '', '', '', '', '', '', '', '#'),
(7, '', '', '', '', '', '', '', '', ''),
(8, '', '', '', '', '', '', '', '', ''),
(9, '', '', '', '', '', '', '', '', '');

DROP TABLE IF EXISTS pong.players;
CREATE TABLE IF NOT EXISTS pong.players (playerNumber, top, bottom, score) AS VALUES
(1, 4, 6, 0),
(2, 4, 6, 0);

DROP TABLE IF EXISTS pong.ball;
-- Direction and skew are separate fields, as this provides more granular control when adjusting the ball's movement
-- Example: xDirection = 1, xSkew = 1 ---> The ball moves right in increments of 1 cell
--          xDirection = -1, xSkew = 1 --> The ball moves left in increments of 1 cell
--          xDirection = -1, xSkew = 2 --> The ball moves left in increments of 2 cells
CREATE TABLE IF NOT EXISTS pong.ball (x, y, xSkew, ySkew, xDirection, yDirection) AS VALUES
(5, 5, 2, 1, 1, -1);

---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------

-- Just a dummy function that should control the skew factor during ball movement
CREATE OR REPLACE FUNCTION pong.setDirectionalSkewOnBall() RETURNS integer AS $$
  DECLARE xSkewNew integer;
  DECLARE ySkewNew integer;
BEGIN
  -- Range from 0 to 2
  SELECT FLOOR(RANDOM() * 3) INTO ySkewNew;
  SELECT CASE
    -- Can't set this to 2, otherwise the ball moves "too fast"
    -- Can't set this to 0, otherwise the ball moves nowhere
    WHEN (ySkewNew = 2) OR (ySkewNew = 0) THEN 1
	-- Range from 1 to 2, this can't be 0 for the same reason stated above
	ELSE FLOOR(RANDOM() * 2) + 1
  END INTO xSkewNew;

  UPDATE pong.ball SET (xSkew, ySkew) = (xSkewNew, ySkewNew);
  RETURN 0;
END;
$$ LANGUAGE plpgsql;
-- Randomise initial ball skew, otherwise the start of the game becomes fairly predictable
SELECT pong.setDirectionalSkewOnBall();
--SELECT * FROM pong.ball;


-- Just a dummy function that should eventually update the player's location
CREATE OR REPLACE FUNCTION pong.movePlayer(playerToMove integer, actionValue integer) RETURNS integer AS $$
  DECLARE playerTop integer;
  DECLARE playerTopNew integer;
  DECLARE playerBottom integer;
  DECLARE playerBottomNew integer;
  DECLARE screenHeight integer;
BEGIN
  SELECT COUNT(*) INTO screenHeight FROM pong.screen;
  -- Keep the player's paddle within the screen height
  SELECT top INTO playerTop FROM pong.players WHERE playernumber = playerToMove;
  SELECT CASE
    WHEN actionValue > 0 AND bottom < screenHeight THEN top + 1
	WHEN actionValue < 0 AND top > 1 THEN top - 1
	ELSE top
  END INTO playerTopNew FROM pong.players WHERE playernumber = playerToMove;
  SELECT bottom INTO playerBottom FROM pong.players WHERE playernumber = playerToMove;
  SELECT CASE
    WHEN actionValue > 0 AND bottom < screenHeight THEN bottom + 1
	WHEN actionValue < 0 AND top > 1 THEN bottom - 1
	ELSE bottom
  END INTO playerBottomNew FROM pong.players WHERE playernumber = playerToMove;
  
  -- Wipe out the paddle and redraw it again at its new coordinates
  UPDATE pong.screen SET (cell1) = (
	  SELECT ''
  ) WHERE playerToMove = 1 AND pong.screen.rowNumber >= playerTop AND pong.screen.rowNumber <= playerBottom;
  UPDATE pong.screen SET (cell1) = (
	  SELECT '#'
  ) WHERE playerToMove = 1 AND pong.screen.rowNumber >= playerTopNew AND pong.screen.rowNumber <= playerBottomNew;
  -- Need to repeat the same UPDATE for the other player, since the field name can't be dynamically assigned
  UPDATE pong.screen SET (cell9) = (
	  SELECT ''
  ) WHERE playerToMove = 2 AND pong.screen.rowNumber >= playerTop AND pong.screen.rowNumber <= playerBottom;
  UPDATE pong.screen SET (cell9) = (
	  SELECT '#'
  ) WHERE playerToMove = 2 AND pong.screen.rowNumber >= playerTopNew AND pong.screen.rowNumber <= playerBottomNew;

  UPDATE pong.players SET (top, bottom) = (playerTopNew, playerBottomNew) WHERE playernumber = playerToMove;
  RETURN 0;
END;
$$ LANGUAGE plpgsql;
--SELECT pong.movePlayer(1, -1);
--SELECT pong.movePlayer(2, 1);
--SELECT * from pong.screen ORDER BY rowNumber ASC;

-- Just a dummy function that should eventually update the ball's location
CREATE OR REPLACE FUNCTION pong.moveBall() RETURNS integer AS $$
  DECLARE xNew integer;
  DECLARE yNew integer;
  DECLARE xDirectionNew integer;
  DECLARE yDirectionNew integer;
  DECLARE rowWithBall integer;
  DECLARE screenHeight integer;
  DECLARE screenWidth integer;
  DECLARE top1 integer;
  DECLARE bottom1 integer;
  DECLARE top2 integer;
  DECLARE bottom2 integer;
  DECLARE whichPlayerHasScored integer;
  DECLARE shouldAdjustBallSkewOnHit boolean;
BEGIN
  SELECT 9 INTO screenWidth;
  SELECT COUNT(*) INTO screenHeight FROM pong.screen;
  SELECT top INTO top1 FROM pong.players WHERE playernumber = 1;
  SELECT bottom INTO bottom1 FROM pong.players WHERE playernumber = 1;
  SELECT top INTO top2 FROM pong.players WHERE playernumber = 2;
  SELECT bottom INTO bottom2 FROM pong.players WHERE playernumber = 2;
  
  -- Calculate the player index that scored based on where the ball will move next.
  -- 0 = No player has scored in this current turn
  SELECT CASE
    WHEN (x + (xDirection * xSkew)) <= 1 AND ((y + (yDirection * ySkew)) < top1 OR (y + (yDirection * ySkew)) > bottom1) THEN 2
	WHEN (x + (xDirection * xSkew)) >= screenWidth AND ((y + (yDirection * ySkew)) < top2 OR (y + (yDirection * ySkew)) > bottom2) THEN 1
	ELSE 0
  END INTO whichPlayerHasScored FROM pong.ball;
  -- Register the score
  UPDATE pong.players SET (score) = (SELECT score + 1) WHERE playernumber = whichPlayerHasScored;
  
  -- Keep the ball within the boundaries of the screen
  SELECT CASE
    -- Reset the X coordinate if the P1 paddle missed the hit
    WHEN whichPlayerHasScored > 0 THEN 5
    ELSE GREATEST(1, LEAST(screenWidth, x + (xDirection * xSkew) ))
  END INTO xNew FROM pong.ball;
  SELECT CASE
    -- Reset the Y coordinate if the P1 paddle missed the hit
    WHEN whichPlayerHasScored > 0 THEN 5
    ELSE GREATEST(1, LEAST(screenHeight, y + (yDirection * ySkew) ))
  END INTO yNew FROM pong.ball;
  -- Reflect the ball when it hits the edge of the screen
  SELECT CASE
    WHEN xNew >= screenWidth OR (xNew = 1 AND yNew >= top1 AND yNew <= bottom1) THEN xDirection * -1
	ELSE xDirection
  END INTO xDirectionNew FROM pong.ball;
  SELECT CASE
    WHEN yNew <= 1 OR yNew >= screenHeight THEN yDirection * -1
	ELSE yDirection
  END INTO yDirectionNew FROM pong.ball;
  
  -- Change the ball's movement pattern when it's reset or bouncing off a paddle
  SELECT FLOOR(RANDOM() * 2) <= 0.9 INTO shouldAdjustBallSkewOnHit;
  PERFORM CASE
    WHEN (whichPlayerHasScored > 0) OR (xDirection != xDirectionNew AND shouldAdjustBallSkewOnHit) THEN pong.setDirectionalSkewOnBall()
  END FROM pong.ball;

  SELECT y INTO rowWithBall FROM pong.ball;
  
  -- Find the row with the ball and blindly remove it from all fields, since Postgres can't access fields by column number
  UPDATE pong.screen SET (cell1, cell2, cell3, cell4, cell5, cell6, cell7, cell8, cell9) = (
	  REPLACE(cell1, '@', ''),
      REPLACE(cell2, '@', ''),
      REPLACE(cell3, '@', ''),
      REPLACE(cell4, '@', ''),
      REPLACE(cell5, '@', ''),
      REPLACE(cell6, '@', ''),
      REPLACE(cell7, '@', ''),
      REPLACE(cell8, '@', ''),
      REPLACE(cell9, '@', '')
  ) WHERE rowNumber = rowWithBall;
  -- Redraw the ball based on its new coordinates
  UPDATE pong.screen SET (cell1, cell2, cell3, cell4, cell5, cell6, cell7, cell8, cell9) = (
	SELECT CASE
      -- Draw the paddle touching the ball, or just the paddle if there's no hit detected
	  WHEN yNew >= top1 AND yNew <= bottom1 THEN 
	    CASE
	      WHEN xNew = 1 THEN '#@'
	      ELSE '#'
	    END
	  ELSE ''
	END,
	CASE
	  WHEN xNew = 2 THEN '@'
	  ELSE ''
	END,
	CASE
	  WHEN xNew = 3 THEN '@'
	  ELSE ''
	END,
	CASE
	  WHEN xNew = 4 THEN '@'
	  ELSE ''
	END,
	CASE
	  WHEN xNew = 5 THEN '@'
	  ELSE ''
	END,
	CASE
	  WHEN xNew = 6 THEN '@'
	  ELSE ''
	END,
	CASE
	  WHEN xNew = 7 THEN '@'
	  ELSE ''
	END,
	CASE
	  WHEN xNew = 8 THEN '@'
	  ELSE ''
	END,
	CASE
	  -- Draw the paddle touching the ball, or just the paddle if there's no hit detected
	  WHEN yNew >= top2 AND yNew <= bottom2 THEN 
	    CASE
	      WHEN xNew = screenWidth THEN '@#'
	      ELSE '#'
	    END
	  ELSE ''
	END
  ) WHERE rowNumber = yNew;

  UPDATE pong.ball SET (x, y, xDirection, yDirection) = (xNew, yNew, xDirectionNew, yDirectionNew);
  RETURN 0;
END;
$$ LANGUAGE plpgsql;

-- Just a dummy function that moves the players and the ball in a single function call
CREATE OR REPLACE FUNCTION pong.playGameWithTwoPlayers(player1Movement integer, player2Movement integer) RETURNS integer AS $$
BEGIN
  -- Ball MUST move after the player, otherwise the paddle can't be drawn when hitting the paddle, otherwise the paddle will draw over the ball's cell
  -- This also means players can manage to reach the ball just as it's about to hit the score zone
  PERFORM pong.movePlayer(1, player1Movement);
  PERFORM pong.movePlayer(2, player2Movement);
  PERFORM pong.moveBall();
  RETURN 0;
END;
$$ LANGUAGE plpgsql;

SELECT pong.playGameWithTwoPlayers(0, 0);
-- ORDER BY is necessary, since UPDATE won't preserve the original row order by default
SELECT * from pong.screen ORDER BY rowNumber ASC;
