#include "api_robot2.h" /* Robot control API */

/*segue-parede.c*/

void delay();

/* main function */
void _start(void)
{
  motor_cfg_t motor0;
  motor0.id = 0;

  motor_cfg_t motor1;
  motor1.id = 1;

  unsigned int distances[16];
  int i = 0;
  int j = 0;
  int d = 0;
  do
  {
      d = read_sonar(3);
      if (d > 1000){
          motor0.speed = 63;
          motor1.speed = 63;
      } else {
          motor0.speed = 0;
          motor1.speed = 63;
      }
      set_motors_speed(&motor0, &motor1);


      // while(i == j){
      //   get_time(&i);
      // }

      // if (i  > 25){
      //   motor0.speed = 31;
      //   motor1.speed = 31;
      // }
      // else{
      //   motor0.speed = 0;
      //   motor1.speed = 31;
      // }

      // if (i > 50){
      //   i = 0;
      //   set_time(0);
      // }
      // if (i > 10)
      //   i = 0;

    // distances[3] = read_sonar(3);
    // distances[4] = read_sonar(4);
    // delay();
    // if (distances[3] < 1000)
    // {
    //   motor0.speed = 0;
    //   motor1.speed = 25;
    //   set_motors_speed(&motor0, &motor1);
    // }
    // else if (distances[4] < 1000)
    // {
    //   motor0.speed = 25;
    //   motor1.speed = 0;
    //   set_motors_speed(&motor0, &motor1);
    // }
    // else{
    //   motor0.speed = 25;
    //   motor1.speed = 25;
    //   set_motors_speed(&motor0, &motor1);
    // }
  } while (1);
}

/* Spend some time doing nothing. */
void delay()
{
  int i;
  /* Not the best way to delay */
  for(i = 0; i < 10000; i++ );
}
