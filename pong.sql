-- Setup commands
CREATE OR REPLACE FUNCTION pong.resetGame(player1CpuDifficulty integer DEFAULT 0, player2CpuDifficulty integer DEFAULT 1) RETURNS integer AS $$
BEGIN
  CREATE SCHEMA IF NOT EXISTS pong;

  DROP TABLE IF EXISTS pong.screen;
  CREATE TABLE IF NOT EXISTS pong.screen (rowNumber serial PRIMARY KEY,
                                          cell1 text,
                                          cell2 text,
                                          cell3 text,
                                          cell4 text,
                                          cell5 text,
                                          cell6 text,
                                          cell7 text,
                                          cell8 text,
                                          cell9 text);
  -- Each cell is 2 characters wide to account for the ball and paddle occupying the same cell on a collision.
  -- By keeping the length of each cell consistent at all times, the table output looks more presentable when viewed using psql.
  -- The convention is that any paddle cell is aligned to its respective side, and any other cell that has to
  -- render a single character is left-aligned.
  INSERT INTO pong.screen VALUES (DEFAULT, '==', '==', '==', '==', '==', '==', '==', '==', '==');
  INSERT INTO pong.screen VALUES (DEFAULT, '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ');
  INSERT INTO pong.screen VALUES (DEFAULT, '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ');
  INSERT INTO pong.screen VALUES (DEFAULT, '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ');
  INSERT INTO pong.screen VALUES (DEFAULT, '# ', '  ', '  ', '  ', '  ', '  ', '  ', '  ', ' #');
  INSERT INTO pong.screen VALUES (DEFAULT, '# ', '  ', '  ', '  ', '@ ', '  ', '  ', '  ', ' #');
  INSERT INTO pong.screen VALUES (DEFAULT, '# ', '  ', '  ', '  ', '  ', '  ', '  ', '  ', ' #');
  INSERT INTO pong.screen VALUES (DEFAULT, '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ');
  INSERT INTO pong.screen VALUES (DEFAULT, '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ');
  INSERT INTO pong.screen VALUES (DEFAULT, '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ', '  ');
  INSERT INTO pong.screen VALUES (DEFAULT, '==', '==', '==', '==', '==', '==', '==', '==', '==');

  DROP TABLE IF EXISTS pong.players;
  CREATE TABLE IF NOT EXISTS pong.players (playerNumber serial PRIMARY KEY,
                                           top integer,
                                           bottom integer,
                                           cpuDifficultyLevel integer,
                                           score integer);
  INSERT INTO pong.players VALUES (DEFAULT, 5, 7, player1CpuDifficulty, 0);
  INSERT INTO pong.players VALUES (DEFAULT, 5, 7, player2CpuDifficulty, 0);

  DROP TABLE IF EXISTS pong.ball;
  -- Single row table constraint, see https://stackoverflow.com/a/25393923
  CREATE TABLE IF NOT EXISTS pong.ball (id boolean PRIMARY KEY DEFAULT TRUE,
                                        x integer,
                                        y integer,
                                        xSkew integer,
                                        ySkew integer,
                                        xDirection integer,
                                        yDirection integer,
                                        xMinimum integer,
                                        xMaximum integer,
                                        yMinimum integer,
                                        yMaximum integer,
                                        CONSTRAINT singleRowTable CHECK (id));
  -- Direction and skew are separate fields, as this provides more granular control when adjusting the ball's movement
  -- Example: xDirection = 1, xSkew = 1 ---> The ball moves right in increments of 1 cell
  --          xDirection = -1, xSkew = 1 --> The ball moves left in increments of 1 cell
  --          xDirection = -1, xSkew = 2 --> The ball moves left in increments of 2 cells
  INSERT INTO pong.ball VALUES (TRUE, 5, 6,  -- X,Y Coordinates
                                      2, 1,  -- X,Y Skew
                                      1, -1, -- X,Y Direction
                                      1, 9,  -- X-axis valid bounds to move in
                                      2, 10  -- Y-axis valid bounds to move in
                                );

  -- Randomise initial ball skew, otherwise the start of the game becomes fairly predictable
  PERFORM pong.setDirectionalSkewOnBall();
  RETURN 0;
END;
$$ LANGUAGE plpgsql;

---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION pong.drawPaddle(playerNumber integer, collidesWithBall boolean) RETURNS text AS $$
  DECLARE paddleCharacter text;
BEGIN
  SELECT CASE
    WHEN playerNumber = 1 THEN
      CASE
        WHEN collidesWithBall = FALSE THEN '# '
        ELSE '#@'
      END
    ELSE
      -- Player 2
      CASE
        WHEN collidesWithBall = FALSE THEN ' #'
        ELSE '@#'
      END
  END INTO paddleCharacter;
  RETURN paddleCharacter;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pong.drawEmptySpace() RETURNS text AS $$
BEGIN
  RETURN '  ';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pong.drawBall() RETURNS text AS $$
BEGIN
  RETURN '@ ';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pong.drawBallOrEmptySpace(isBall boolean) RETURNS text AS $$
  DECLARE cellCharacter text;
BEGIN
  SELECT CASE
    WHEN isBall THEN pong.drawBall()
    ELSE pong.drawEmptySpace()
  END INTO cellCharacter;
  RETURN cellCharacter;
END;
$$ LANGUAGE plpgsql;

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

-- Just a dummy function that determines the new value for a ball's direction on a given axis of movement
CREATE OR REPLACE FUNCTION pong.calculateNewBallDirection(directionOriginal integer) RETURNS integer AS $$
  DECLARE directionNew integer;
BEGIN
  SELECT CASE
    WHEN FLOOR(RANDOM() * 2) <= 0.9 THEN directionOriginal * -1
    ELSE directionOriginal
  END INTO directionNew;
  RETURN directionNew;
END;
$$ LANGUAGE plpgsql;

-- Just a dummy function that should decide whether the ball's movement changes on hit
CREATE OR REPLACE FUNCTION pong.shouldAdjustBallSkewOnHit() RETURNS boolean AS $$
BEGIN
  RETURN FLOOR(RANDOM() * 2) <= 0.9;
END;
$$ LANGUAGE plpgsql;

-- Just a dummy function that should eventually update the player's location
CREATE OR REPLACE FUNCTION pong.movePlayer(playerToMove integer, actionValue integer) RETURNS integer AS $$
  DECLARE playerTop integer;
  DECLARE playerTopNew integer;
  DECLARE playerBottom integer;
  DECLARE playerBottomNew integer;
  DECLARE screenRowFirst integer;
  DECLARE screenRowFinal integer;
BEGIN
  SELECT yMinimum, yMaximum INTO screenRowFirst, screenRowFinal FROM pong.ball;
  -- Keep the player's paddle within the screen height
  SELECT top INTO playerTop FROM pong.players WHERE playernumber = playerToMove;
  SELECT CASE
    WHEN actionValue > 0 AND bottom < screenRowFinal THEN top + 1
	WHEN actionValue < 0 AND top > screenRowFirst THEN top - 1
	ELSE top
  END INTO playerTopNew FROM pong.players WHERE playernumber = playerToMove;
  SELECT bottom INTO playerBottom FROM pong.players WHERE playernumber = playerToMove;
  SELECT CASE
    WHEN actionValue > 0 AND bottom < screenRowFinal THEN bottom + 1
	WHEN actionValue < 0 AND top > screenRowFirst THEN bottom - 1
	ELSE bottom
  END INTO playerBottomNew FROM pong.players WHERE playernumber = playerToMove;
  
  -- Wipe out the paddle and redraw it again at its new coordinates
  UPDATE pong.screen SET (cell1) = (
	  SELECT pong.drawEmptySpace()
  ) WHERE playerToMove = 1 AND pong.screen.rowNumber >= playerTop AND pong.screen.rowNumber <= playerBottom;
  UPDATE pong.screen SET (cell1) = (
	  SELECT pong.drawPaddle(1, FALSE)
  ) WHERE playerToMove = 1 AND pong.screen.rowNumber >= playerTopNew AND pong.screen.rowNumber <= playerBottomNew;
  -- Need to repeat the same UPDATE for the other player, since the field name can't be dynamically assigned
  UPDATE pong.screen SET (cell9) = (
	  SELECT pong.drawEmptySpace()
  ) WHERE playerToMove = 2 AND pong.screen.rowNumber >= playerTop AND pong.screen.rowNumber <= playerBottom;
  UPDATE pong.screen SET (cell9) = (
	  SELECT pong.drawPaddle(2, FALSE)
  ) WHERE playerToMove = 2 AND pong.screen.rowNumber >= playerTopNew AND pong.screen.rowNumber <= playerBottomNew;

  UPDATE pong.players SET (top, bottom) = (playerTopNew, playerBottomNew) WHERE playernumber = playerToMove;
  RETURN 0;
END;
$$ LANGUAGE plpgsql;
--SELECT pong.movePlayer(1, -1);
--SELECT pong.movePlayer(2, 1);
--SELECT * from pong.screen ORDER BY rowNumber ASC;

CREATE OR REPLACE FUNCTION pong.incrementScore(playerWhoScored integer) RETURNS integer AS $$
BEGIN
  UPDATE pong.players SET (score) = (SELECT score + 1) WHERE playernumber = playerWhoScored;
  RETURN 0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pong.clearBallFromScreen() RETURNS integer AS $$
  DECLARE rowWithBall integer;
BEGIN
  SELECT y INTO rowWithBall FROM pong.ball;
  -- Find the row with the ball and blindly remove it from all fields, since Postgres can't access fields by column number
  -- Only one row needs to be updated, on the assumption that there is only ever one ball on the screen
  UPDATE pong.screen SET (cell1, cell2, cell3, cell4, cell5, cell6, cell7, cell8, cell9) = (
    REPLACE(cell1, pong.drawBall(), pong.drawEmptySpace()),
    REPLACE(cell2, pong.drawBall(), pong.drawEmptySpace()),
    REPLACE(cell3, pong.drawBall(), pong.drawEmptySpace()),
    REPLACE(cell4, pong.drawBall(), pong.drawEmptySpace()),
    REPLACE(cell5, pong.drawBall(), pong.drawEmptySpace()),
    REPLACE(cell6, pong.drawBall(), pong.drawEmptySpace()),
    REPLACE(cell7, pong.drawBall(), pong.drawEmptySpace()),
    REPLACE(cell8, pong.drawBall(), pong.drawEmptySpace()),
    REPLACE(cell9, pong.drawBall(), pong.drawEmptySpace())
  ) WHERE rowNumber = rowWithBall;
  RETURN 0;
END;
$$ LANGUAGE plpgsql;

-- Just a dummy function that should eventually update the ball's location
CREATE OR REPLACE FUNCTION pong.moveBall() RETURNS integer AS $$
  DECLARE xNew integer;
  DECLARE yNew integer;
  DECLARE xDirectionNew integer;
  DECLARE yDirectionNew integer;
  DECLARE xWithSkewedDirection integer;
  DECLARE yWithSkewedDirection integer;
  DECLARE screenRowFirst integer;
  DECLARE screenRowFinal integer;
  DECLARE screenColumnFirst integer;
  DECLARE screenColumnFinal integer;
  DECLARE top1 integer;
  DECLARE bottom1 integer;
  DECLARE top2 integer;
  DECLARE bottom2 integer;
  DECLARE whichPlayerHasScored integer;
BEGIN
  SELECT xMinimum, xMaximum, yMinimum, yMaximum INTO screenColumnFirst, screenColumnFinal, screenRowFirst, screenRowFinal FROM pong.ball;
  SELECT top, bottom INTO top1, bottom1 FROM pong.players WHERE playernumber = 1;
  SELECT top, bottom INTO top2, bottom2 FROM pong.players WHERE playernumber = 2;
  SELECT (x + (xDirection * xSkew)), (y + (yDirection * ySkew)) INTO xWithSkewedDirection, yWithSkewedDirection FROM pong.ball;
  
  -- Calculate the player index that scored based on where the ball will move next.
  -- 0 = No player has scored in this current turn
  SELECT CASE
    WHEN xWithSkewedDirection <= screenColumnFirst AND (yWithSkewedDirection < top1 OR yWithSkewedDirection > bottom1) THEN 2
	WHEN xWithSkewedDirection >= screenColumnFinal AND (yWithSkewedDirection < top2 OR yWithSkewedDirection > bottom2) THEN 1
	ELSE 0
  END INTO whichPlayerHasScored FROM pong.ball;
  
  -- Keep the ball within the boundaries of the screen
  SELECT CASE
    -- Reset the X coordinate if the P1 paddle missed the hit
    WHEN whichPlayerHasScored > 0 THEN 5
    ELSE GREATEST(screenColumnFirst, LEAST(screenColumnFinal, xWithSkewedDirection))
  END INTO xNew FROM pong.ball;
  SELECT CASE
    -- Reset the Y coordinate if the P1 paddle missed the hit
    WHEN whichPlayerHasScored > 0 THEN 5
    ELSE GREATEST(screenRowFirst, LEAST(screenRowFinal, yWithSkewedDirection))
  END INTO yNew FROM pong.ball;
  -- Reflect the ball when it hits the edge of the screen
  SELECT CASE
    WHEN whichPlayerHasScored > 0 THEN pong.calculateNewBallDirection(xDirection)
    WHEN xNew <= screenColumnFirst OR xNew >= screenColumnFinal THEN xDirection * -1
	ELSE xDirection
  END INTO xDirectionNew FROM pong.ball;
  SELECT CASE
    -- Remove the check on xNew to provide a more predictable travel path when the ball hits the paddle
    WHEN (whichPlayerHasScored > 0) OR (xNew <= screenColumnFirst OR xNew >= screenColumnFinal) THEN pong.calculateNewBallDirection(yDirection)
    WHEN yNew <= screenRowFirst OR yNew >= screenRowFinal THEN yDirection * -1
	ELSE yDirection
  END INTO yDirectionNew FROM pong.ball;
  
  -- Change the ball's movement pattern when it's reset or bouncing off a paddle
  PERFORM CASE
    WHEN (whichPlayerHasScored > 0) OR (xDirection != xDirectionNew AND pong.shouldAdjustBallSkewOnHit()) THEN pong.setDirectionalSkewOnBall()
  END FROM pong.ball;

  -- Register the score
  PERFORM pong.incrementScore(whichPlayerHasScored);
  -- Redraw the ball based on its new coordinates
  PERFORM pong.clearBallFromScreen();
  UPDATE pong.screen SET (cell1, cell2, cell3, cell4, cell5, cell6, cell7, cell8, cell9) = (
	SELECT CASE
      -- Draw the paddle touching the ball, or just the paddle if there's no hit detected
	  WHEN yNew >= top1 AND yNew <= bottom1 THEN pong.drawPaddle(1, xNew = screenColumnFirst)
	  ELSE pong.drawEmptySpace()
	END,
	pong.drawBallOrEmptySpace(xNew = 2),
	pong.drawBallOrEmptySpace(xNew = 3),
	pong.drawBallOrEmptySpace(xNew = 4),
	pong.drawBallOrEmptySpace(xNew = 5),
	pong.drawBallOrEmptySpace(xNew = 6),
	pong.drawBallOrEmptySpace(xNew = 7),
	pong.drawBallOrEmptySpace(xNew = 8),
	CASE
	  -- Draw the paddle touching the ball, or just the paddle if there's no hit detected
	  WHEN yNew >= top2 AND yNew <= bottom2 THEN pong.drawPaddle(2, xNew = screenColumnFinal)
	  ELSE pong.drawEmptySpace()
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

-- Just a dummy function that moves one player with user input, the other with calculations and the ball in a single function call
CREATE OR REPLACE FUNCTION pong.playGameWithOnePlayer(player integer, playerMovement integer) RETURNS integer AS $$
  DECLARE playerOther integer;
  DECLARE playerMovementOther integer;
  DECLARE ballY integer;
  DECLARE playerOtherDifficultyLevel integer;
BEGIN
  -- Determine who the CPU player is
  SELECT CASE
    WHEN player = 1 THEN 2
    ELSE 1
  END INTO playerOther;
  SELECT cpuDifficultyLevel INTO playerOtherDifficultyLevel FROM pong.players WHERE playerNumber = playerOther;
  -- More difficult CPU opponents will take into consideration the ball's movement pattern
  SELECT CASE
    WHEN playerOtherDifficultyLevel > 0 THEN y + (yDirection * ySkew)
    ELSE y
  END INTO ballY FROM pong.ball;
  -- Pick a direction to go in - This is where the "brains" of the CPU movement are represented
  SELECT CASE
    WHEN ballY < top THEN -1
    WHEN ballY > bottom THEN 1
    ELSE 0
  END INTO playerMovementOther FROM pong.players WHERE playerNumber = playerOther;

  PERFORM CASE
    WHEN playerOther = 1 THEN pong.playGameWithTwoPlayers(playerMovementOther, playerMovement)
    ELSE pong.playGameWithTwoPlayers(playerMovement, playerMovementOther)
  END;
  RETURN 0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pong.printScreen() RETURNS TABLE (
  cell1 text,
  cell2 text,
  cell3 text,
  cell4 text,
  cell5 text,
  cell6 text,
  cell7 text,
  cell8 text,
  cell9 text) AS $$
BEGIN
  -- ORDER BY is necessary, since UPDATE won't preserve the original row order by default
  RETURN QUERY
  SELECT screen.cell1, screen.cell2, screen.cell3, screen.cell4, screen.cell5, screen.cell6, screen.cell7, screen.cell8, screen.cell9
  FROM pong.screen ORDER BY rowNumber ASC;
END;
$$ LANGUAGE plpgsql;

SELECT pong.resetGame();

SELECT pong.playGameWithTwoPlayers(0, 0);

-- Set the difficulty for one of the players in 1P mode
--UPDATE pong.players SET (cpuDifficultyLevel) = (SELECT 1) WHERE playerNumber = 1;
--SELECT pong.playGameWithOnePlayer(2, 0);

SELECT * FROM pong.printScreen();
